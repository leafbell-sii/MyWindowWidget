<#
.SYNOPSIS
  Google Tasks helper for the MyWindowWidget Tasks skins.

.DESCRIPTION
  The Tasks skins start this script through the RunCommand plugin
  (hidden window) and read the result from
  @Resources\Cache\tasks<Slot>.txt. Nothing is written to STDOUT for
  the skin.

  Google Tasks does not accept API keys: every request needs an OAuth
  2.0 access token (scope .../auth/tasks). This script uses the
  "installed app" flow: loopback redirect + PKCE, Desktop app client.

  Actions
    setup     One-time sign-in, run by the user in a console window:
                -ClientSecretFile <client_secret_....json>
              Opens the browser, then stores client id / secret /
              refresh token encrypted with Windows DPAPI (current
              user only) in %LOCALAPPDATA%\MyWindowWidget\GoogleTasks.
              The JSON file can be deleted afterwards.
    signout   Revokes the refresh token at Google, deletes the stored
              credential and the Tasks caches.
    fetch     Writes the task lists and the open tasks of one list.
    add       Adds the title in Cache\tasks<Slot>.new (UTF-8, written by
              Tasks.lua) at the top of the list, then fetches.
    complete  Marks -TaskId as completed, then fetches.

  The list shown by a slot is -ListId. When it is empty or no longer
  exists, slot N shows the N-th list (wrapping around).

  Cache file (UTF-8 without BOM, tab separated, one record per line):
    status   <ok|setup|auth|offline|error>  <detail>
    updated  <yyyy-MM-dd HH:mm>           last successful fetch
    list     <id>  <1 = shown in this slot, else 0>  <title>
    task     <id>  <depth 0|1>  <due yyyy-MM-dd or empty>  <title>
  Tasks are in Google's order: top-level tasks by position, each
  followed by its subtasks. On a failed fetch only the status line
  changes, so the skin keeps showing the last good data.

  Secrets (client secret, refresh / access tokens) never go to STDOUT,
  the cache files or the Rainmeter log.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File GTasks.ps1 -Action setup -ClientSecretFile "$env:USERPROFILE\Downloads\client_secret.json"
#>
param(
  [ValidateSet('setup', 'signout', 'fetch', 'add', 'complete')]
  [string]$Action = 'fetch',
  [ValidateRange(1, 99)]
  [int]$Slot = 1,
  [string]$ListId = '',
  [string]$TaskId = '',
  [string]$ClientSecretFile = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Security

$Scope      = 'https://www.googleapis.com/auth/tasks'
$AuthUrl    = 'https://accounts.google.com/o/oauth2/v2/auth'
$TokenUrl   = 'https://oauth2.googleapis.com/token'
$RevokeUrl  = 'https://oauth2.googleapis.com/revoke'
$ApiBase    = 'https://tasks.googleapis.com/tasks/v1'
$TimeoutSec = 20
$SignInWaitSec = 300

$StoreDir  = Join-Path $env:LOCALAPPDATA 'MyWindowWidget\GoogleTasks'
$CredFile  = Join-Path $StoreDir 'credential.bin'
$TokenFile = Join-Path $StoreDir 'access.bin'
$CacheDir  = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Cache'))
$OutFile   = Join-Path $CacheDir "tasks$Slot.txt"
$NewFile   = Join-Path $CacheDir "tasks$Slot.new"
$Utf8      = New-Object Text.UTF8Encoding $false
$Entropy   = [Text.Encoding]::ASCII.GetBytes('MyWindowWidget.GoogleTasks')
# Google list / task ids are URL-safe base64. Anything else is refused,
# so a value from the skin can never change the command or the URL.
$IdPattern = '^[A-Za-z0-9_-]{1,256}$'

# ---- Errors ---------------------------------------------------------
# Data['code'] becomes the status word in the cache file.
function Fail([string]$Code, [string]$Detail) {
  $e = New-Object Exception $Detail
  $e.Data['code'] = $Code
  throw $e
}

function Get-ErrorCode($ErrorRecord) {
  $c = $ErrorRecord.Exception.Data['code']
  if ($c -in 'setup', 'auth', 'offline') { return $c }
  return 'error'
}

# ---- DPAPI-protected storage ----------------------------------------
function Save-Secret([string]$Path, $Object) {
  New-Item -ItemType Directory -Force $StoreDir | Out-Null
  $plain = $Utf8.GetBytes(($Object | ConvertTo-Json -Compress))
  $blob = [Security.Cryptography.ProtectedData]::Protect($plain, $Entropy, 'CurrentUser')
  [IO.File]::WriteAllBytes($Path, $blob)
}

function Read-Secret([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $plain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($Path), $Entropy, 'CurrentUser')
    return ($Utf8.GetString($plain) | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Get-UnixNow { [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

# ---- HTTP -----------------------------------------------------------
# Returns the parsed JSON body (decoded as UTF-8 regardless of headers).
# HTTP errors throw with Data['status'] and Data['error'] (Google's
# "error" field, when there is one). No response at all = offline.
function Invoke-Http([string]$Method, [string]$Uri, $Headers, $Body, [string]$ContentType) {
  $p = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true; TimeoutSec = $TimeoutSec }
  if ($Headers) { $p.Headers = $Headers }
  if ($null -ne $Body) { $p.Body = $Body; $p.ContentType = $ContentType }
  try {
    $r = Invoke-WebRequest @p
  } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if (-not $resp) { Fail 'offline' 'No connection' }
    $status = [int]$resp.StatusCode
    $text = ''
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
    $errName = ''
    try {
      $j = $text | ConvertFrom-Json
      if ($j.error -is [string]) { $errName = $j.error }
      elseif ($j.error.status) { $errName = [string]$j.error.status }
    } catch { }
    $e = New-Object Exception ("HTTP $status")
    $e.Data['code'] = 'http'
    $e.Data['status'] = $status
    $e.Data['error'] = $errName
    throw $e
  }
  $raw = $r.RawContentStream.ToArray()
  if ($raw.Length -eq 0) { return $null }
  return ($Utf8.GetString($raw) | ConvertFrom-Json)
}

function Get-AccessToken([switch]$Renew) {
  $cred = Read-Secret $CredFile
  if (-not $cred -or -not $cred.refresh_token) { Fail 'setup' 'Not connected' }
  if (-not $Renew) {
    $t = Read-Secret $TokenFile
    if ($t -and $t.token -and [int]$t.expires -gt ((Get-UnixNow) + 60)) { return [string]$t.token }
  }
  $form = @{
    client_id     = $cred.client_id
    client_secret = $cred.client_secret
    grant_type    = 'refresh_token'
    refresh_token = $cred.refresh_token
  }
  try {
    $r = Invoke-Http 'Post' $TokenUrl $null $form 'application/x-www-form-urlencoded'
  } catch {
    # invalid_grant: refresh token revoked or expired (e.g. 7-day limit
    # of a consent screen still in "Testing"). Only a new sign-in helps.
    if ($_.Exception.Data['error'] -in 'invalid_grant', 'invalid_client', 'unauthorized_client') {
      Fail 'auth' 'Sign-in expired'
    }
    throw
  }
  Save-Secret $TokenFile @{ token = $r.access_token; expires = (Get-UnixNow) + [int]$r.expires_in }
  return [string]$r.access_token
}

function Invoke-Api([string]$Method, [string]$Path, $Json) {
  for ($try = 0; $try -lt 2; $try++) {
    $token = Get-AccessToken -Renew:($try -gt 0)
    $body = $null
    $ct = ''
    if ($null -ne $Json) {
      $body = $Utf8.GetBytes(($Json | ConvertTo-Json -Compress))
      $ct = 'application/json; charset=utf-8'
    }
    try {
      return Invoke-Http $Method ($ApiBase + $Path) @{ Authorization = "Bearer $token" } $body $ct
    } catch {
      # Access token rejected (expired early, revoked): renew once.
      if ($try -eq 0 -and $_.Exception.Data['status'] -eq 401) { continue }
      throw
    }
  }
}

function Get-AllItems([string]$Path) {
  $items = New-Object System.Collections.ArrayList
  $page = ''
  do {
    $p = $Path
    if ($page) { $p += '&pageToken=' + [Uri]::EscapeDataString($page) }
    $r = Invoke-Api 'Get' $p $null
    if ($r.items) { foreach ($i in $r.items) { [void]$items.Add($i) } }
    $page = [string]$r.nextPageToken
  } while ($page)
  return , $items.ToArray()
}

function Get-EscapedId([string]$Id) { [Uri]::EscapeDataString($Id) }

# ---- Cache file -----------------------------------------------------
function Get-Clean($s) { ([string]$s -replace '[\t\r\n]+', ' ').Trim() }

function Write-Cache([string[]]$Lines) {
  New-Item -ItemType Directory -Force $CacheDir | Out-Null
  [IO.File]::WriteAllText($OutFile, (($Lines -join "`n") + "`n"), $Utf8)
}

# Replaces only the status line. Not connected / signed out: drop the
# old data too, it must not stay on screen.
function Write-Status([string]$Code, [string]$Detail) {
  $keep = @()
  if ($Code -notin 'setup', 'auth' -and (Test-Path -LiteralPath $OutFile)) {
    $keep = @([IO.File]::ReadAllLines($OutFile, $Utf8) | Where-Object { $_ -and -not $_.StartsWith("status`t") })
  }
  Write-Cache (@("status`t$Code`t$(Get-Clean $Detail)") + $keep)
}

function Get-DueDate($Due) {
  if (-not $Due) { return '' }
  if ($Due -is [datetime]) { return $Due.ToUniversalTime().ToString('yyyy-MM-dd') }
  $s = [string]$Due
  if ($s.Length -ge 10) { return $s.Substring(0, 10) }
  return ''
}

# ---- One-time sign-in -----------------------------------------------
function ConvertTo-Base64Url([byte[]]$Bytes) {
  [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-RandomBytes([int]$Count) {
  $b = New-Object byte[] $Count
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($b)
  $rng.Dispose()
  return , $b
}

# Minimal HTTP server on 127.0.0.1 for the OAuth redirect. TcpListener
# needs no admin rights or URL ACL (HttpListener would). Other requests
# (favicon, browser pre-connects) get a 404 and the wait goes on.
function Wait-Redirect($Listener) {
  $deadline = (Get-Date).AddSeconds($SignInWaitSec)
  while ((Get-Date) -lt $deadline) {
    if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 200; continue }
    $client = $Listener.AcceptTcpClient()
    try {
      $client.ReceiveTimeout = 5000
      $stream = $client.GetStream()
      $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII)
      $first = $reader.ReadLine()
      while ($true) {
        $h = $reader.ReadLine()
        if ($null -eq $h -or $h -eq '') { break }
      }
      $query = @{}
      if ($first -match '^GET \S*?\?(\S*) HTTP/') {
        foreach ($pair in $Matches[1].Split('&')) {
          $kv = $pair.Split('=', 2)
          if ($kv.Count -eq 2) { $query[$kv[0]] = [Uri]::UnescapeDataString($kv[1].Replace('+', ' ')) }
        }
      }
      $done = $query.ContainsKey('code') -or $query.ContainsKey('error')
      if ($done) {
        $status = '200 OK'
        $html = '<!doctype html><meta charset="utf-8"><title>MyWindowWidget</title>' +
                '<body style="font-family:Segoe UI,sans-serif;padding:40px">' +
                '<h2>MyWindowWidget</h2><p>You can close this tab and go back to the console window.</p>'
      } else {
        $status = '404 Not Found'
        $html = ''
      }
      $bytes = $Utf8.GetBytes($html)
      $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
      $stream.Write($head, 0, $head.Length)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
      if ($done) { return $query }
    } catch {
      # Pre-connect without a request (read timeout) - ignore.
    } finally {
      $client.Close()
    }
  }
  throw "No answer from the browser within $SignInWaitSec seconds."
}

function Invoke-Setup {
  if (-not $ClientSecretFile -or -not (Test-Path -LiteralPath $ClientSecretFile)) {
    Write-Host 'Usage: GTasks.ps1 -Action setup -ClientSecretFile <client_secret_....json>'
    Write-Host 'The JSON comes from Google Cloud Console > Google Auth Platform > Clients'
    Write-Host '(client type "Desktop app") > Download JSON. See README, "Google Tasks".'
    exit 2
  }
  $json = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ClientSecretFile).Path, $Utf8) | ConvertFrom-Json
  $client = $json.installed
  if (-not $client -or -not $client.client_id -or -not $client.client_secret) {
    Write-Host 'This file is not a "Desktop app" OAuth client. Create a client of type'
    Write-Host '"Desktop app" and download its JSON again.'
    exit 2
  }

  $verifier  = ConvertTo-Base64Url (Get-RandomBytes 48)
  $sha       = [Security.Cryptography.SHA256]::Create()
  $challenge = ConvertTo-Base64Url ($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier)))
  $sha.Dispose()
  $state     = ConvertTo-Base64Url (Get-RandomBytes 24)

  $listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Loopback), 0
  $listener.Start()
  try {
    $redirect = 'http://127.0.0.1:' + $listener.LocalEndpoint.Port
    $q = [ordered]@{
      client_id             = $client.client_id
      redirect_uri          = $redirect
      response_type         = 'code'
      scope                 = $Scope
      code_challenge        = $challenge
      code_challenge_method = 'S256'
      state                 = $state
      prompt                = 'consent'
    }
    $url = $AuthUrl + '?' + (($q.GetEnumerator() | ForEach-Object { $_.Key + '=' + [Uri]::EscapeDataString([string]$_.Value) }) -join '&')
    Write-Host 'Opening Google sign-in in your browser.'
    Write-Host 'If it does not open, paste this address into the browser:'
    Write-Host ''
    Write-Host $url
    Write-Host ''
    Start-Process $url
    Write-Host "Waiting for the sign-in (up to $SignInWaitSec seconds)..."
    $answer = Wait-Redirect $listener
  } finally {
    $listener.Stop()
  }

  if ($answer['state'] -ne $state) { Write-Host 'Sign-in answer did not match this request. Try again.'; exit 1 }
  if ($answer.ContainsKey('error')) { Write-Host ('Sign-in was not completed: ' + $answer['error']); exit 1 }

  $form = @{
    code          = $answer['code']
    client_id     = $client.client_id
    client_secret = $client.client_secret
    redirect_uri  = $redirect
    grant_type    = 'authorization_code'
    code_verifier = $verifier
  }
  try {
    $tok = Invoke-Http 'Post' $TokenUrl $null $form 'application/x-www-form-urlencoded'
  } catch {
    Write-Host ('Google refused the sign-in code: ' + $_.Exception.Message + ' ' + $_.Exception.Data['error'])
    exit 1
  }
  if (-not $tok.refresh_token) { Write-Host 'Google did not return a refresh token. Run the setup again.'; exit 1 }

  Save-Secret $CredFile @{ client_id = $client.client_id; client_secret = $client.client_secret; refresh_token = $tok.refresh_token }
  Save-Secret $TokenFile @{ token = $tok.access_token; expires = (Get-UnixNow) + [int]$tok.expires_in }

  $lists = Get-AllItems '/users/@me/lists?maxResults=100'
  Write-Host ''
  Write-Host ("Connected. {0} task list(s):" -f $lists.Count)
  $n = 1
  foreach ($l in $lists) { Write-Host ("  Tasks\List{0}: {1}" -f $n, $l.title); $n++ }
  Write-Host ''
  Write-Host 'Widget slot ListN shows list N by default; < > on a widget picks another list.'
  Write-Host 'The credential is stored encrypted for this Windows user in:'
  Write-Host "  $StoreDir"
  Write-Host 'You can now delete the downloaded client secret JSON file.'
  Write-Host 'Click a Tasks widget title (or wait a few minutes) to load the tasks.'
}

function Invoke-Signout {
  $cred = Read-Secret $CredFile
  if ($cred -and $cred.refresh_token) {
    try {
      Invoke-Http 'Post' $RevokeUrl $null @{ token = $cred.refresh_token } 'application/x-www-form-urlencoded' | Out-Null
      Write-Host 'Access revoked at Google.'
    } catch {
      Write-Host 'Could not revoke at Google. Remove access by hand at https://myaccount.google.com/permissions'
    }
  }
  Remove-Item -LiteralPath $CredFile, $TokenFile -Force -ErrorAction SilentlyContinue
  Get-ChildItem -LiteralPath $CacheDir -Filter 'tasks*.*' -ErrorAction SilentlyContinue | Remove-Item -Force
  Write-Host 'Signed out. Stored credential and Tasks caches deleted.'
}

# ---- Main -----------------------------------------------------------
if ($Action -eq 'setup') { Invoke-Setup; exit 0 }
if ($Action -eq 'signout') { Invoke-Signout; exit 0 }

try {
  if ($ListId -notmatch $IdPattern) { $ListId = '' }

  $lists = Get-AllItems '/users/@me/lists?maxResults=100'
  if ($lists.Count -eq 0) { Fail 'error' 'No task lists' }
  $shown = $null
  if ($ListId) { $shown = $lists | Where-Object { $_.id -eq $ListId } | Select-Object -First 1 }
  if (-not $shown) { $shown = $lists[($Slot - 1) % $lists.Count] }
  $listPath = '/lists/' + (Get-EscapedId $shown.id) + '/tasks'

  # A failed change still fetches, so the list on screen is the truth.
  $note = ''
  if ($Action -eq 'add' -and (Test-Path -LiteralPath $NewFile)) {
    $title = Get-Clean ([IO.File]::ReadAllText($NewFile, $Utf8))
    if ($title.Length -gt 1024) { $title = $title.Substring(0, 1024) }
    if ($title) {
      try {
        Invoke-Api 'Post' $listPath @{ title = $title } | Out-Null
        Remove-Item -LiteralPath $NewFile -Force
      } catch {
        if ((Get-ErrorCode $_) -ne 'error') { throw }
        $note = 'Could not add the task'
      }
    } else {
      Remove-Item -LiteralPath $NewFile -Force
    }
  } elseif ($Action -eq 'complete') {
    if ($TaskId -notmatch $IdPattern) {
      $note = 'Unknown task'
    } else {
      try {
        Invoke-Api 'Patch' ($listPath + '/' + $TaskId) @{ status = 'completed' } | Out-Null
      } catch {
        if ((Get-ErrorCode $_) -ne 'error') { throw }
        $note = 'Could not complete the task'
      }
    }
  }

  $all = Get-AllItems ($listPath + '?showCompleted=false&showHidden=false&maxResults=100')
  $all = @($all | Where-Object { $_.status -ne 'completed' -and -not $_.deleted })
  $ids = @{}
  foreach ($t in $all) { $ids[[string]$t.id] = $true }
  $children = @{}
  $top = New-Object System.Collections.ArrayList
  foreach ($t in ($all | Sort-Object { [string]$_.position })) {
    $p = [string]$t.parent
    if ($p -and $ids.ContainsKey($p)) {
      if (-not $children.ContainsKey($p)) { $children[$p] = New-Object System.Collections.ArrayList }
      [void]$children[$p].Add($t)
    } else {
      [void]$top.Add($t)
    }
  }

  $lines = New-Object System.Collections.Generic.List[string]
  if ($note) { $lines.Add("status`terror`t$note") } else { $lines.Add("status`tok`t") }
  $lines.Add("updated`t" + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  foreach ($l in $lists) {
    $flag = if ($l.id -eq $shown.id) { '1' } else { '0' }
    $lines.Add("list`t$($l.id)`t$flag`t$(Get-Clean $l.title)")
  }
  foreach ($t in $top) {
    $lines.Add("task`t$($t.id)`t0`t$(Get-DueDate $t.due)`t$(Get-Clean $t.title)")
    if ($children.ContainsKey([string]$t.id)) {
      foreach ($c in $children[[string]$t.id]) {
        $lines.Add("task`t$($c.id)`t1`t$(Get-DueDate $c.due)`t$(Get-Clean $c.title)")
      }
    }
  }
  Write-Cache $lines.ToArray()
  exit 0
} catch {
  $code = Get-ErrorCode $_
  $detail = switch ($code) {
    'setup'   { 'Not connected' }
    'auth'    { 'Sign-in expired' }
    'offline' { 'Offline' }
    default   { $_.Exception.Message }
  }
  Write-Status $code $detail
  exit 1
}
