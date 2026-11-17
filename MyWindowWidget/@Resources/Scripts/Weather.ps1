<#
.SYNOPSIS
  Weather helper for the MyWindowWidget Clock skin.

.DESCRIPTION
  The Clock skin starts this script through the RunCommand plugin
  (hidden window) and reads the result from @Resources\Cache\weather.txt.
  Nothing is written to STDOUT for the skin.

  1. Location: -Lat / -Lon when given (WeatherLatitude / Longitude in
     Variables.inc), otherwise the Windows location service
     (System.Device.Location, needs "Let desktop apps access your
     location" in Windows Settings > Privacy & security > Location).
     If Windows has no fix in time, the last location in the cache is
     used. Coordinates are rounded to 2 decimals (~1 km) before they
     leave the PC or go into the cache.
  2. Place name: BigDataCloud's free client-side reverse geocoding
     (https://www.bigdatacloud.com/free-api/free-reverse-geocode-to-city-api),
     only when the rounded location or the language changed. Its fair
     use terms ask for the device's own location from the platform
     location API, called from the device - which is what this does.
     Skipped when -NoPlace is given (the skin has WeatherPlace set).
  3. Weather: Open-Meteo forecast API (https://open-meteo.com/en/docs),
     no key, current conditions + today's high / low, always metric
     (the skin converts to Fahrenheit).

  Cache file (UTF-8 without BOM, tab separated, one record per line):
    status   <ok|nolocation|offline|error>  <detail>
    updated  <yyyy-MM-dd HH:mm:ss>        last successful weather (local time)
    location <lat> <lon> <windows|fixed|cached>
    place    <lat> <lon> <lang> <name> <full name>
    current  <temp C> <feels like C> <humidity %> <WMO code> <is_day 0|1> <wind km/h>
    today    <max C> <min C>
  On a failure only the status line changes, so the skin keeps showing
  the last good data.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File Weather.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File Weather.ps1 -Lat 37.57 -Lon 126.98 -Lang en
#>
param(
  [string]$Lat = '',
  [string]$Lon = '',
  [string]$Lang = '',
  [switch]$NoPlace
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$WeatherUrl = 'https://api.open-meteo.com/v1/forecast'
$PlaceUrl   = 'https://api.bigdatacloud.net/data/reverse-geocode-client'
$TimeoutSec = 20
$LocateWaitSec = 15

$CacheDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Cache'))
$OutFile  = Join-Path $CacheDir 'weather.txt'
$Utf8     = New-Object Text.UTF8Encoding $false
$Inv      = [Globalization.CultureInfo]::InvariantCulture

# ---- Cache ----------------------------------------------------------
$cache = [ordered]@{}
if (Test-Path $OutFile) {
  foreach ($line in [IO.File]::ReadAllLines($OutFile, $Utf8)) {
    $f = $line -split "`t"
    if ($f.Count -ge 2) { $cache[$f[0]] = $f }
  }
}

function Clean([string]$s) { return (($s -replace '[\t\r\n]+', ' ').Trim()) }

function Save-Cache([string]$Status, [string]$Detail) {
  $cache['status'] = @('status', $Status, (Clean $Detail))
  $order = 'status', 'updated', 'location', 'place', 'current', 'today'
  $lines = foreach ($k in $order) { if ($cache.Contains($k)) { $cache[$k] -join "`t" } }
  if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir | Out-Null }
  $tmp = "$OutFile.tmp"
  [IO.File]::WriteAllText($tmp, (($lines -join "`n") + "`n"), $Utf8)
  Move-Item -LiteralPath $tmp -Destination $OutFile -Force
}

function Num($v) { return ([double]$v).ToString('0.##', $Inv) }

function Is-Offline($err) {
  $ex = $err.Exception
  while ($ex) {
    if ($ex -is [Net.WebException] -and $ex.Status -ne [Net.WebExceptionStatus]::ProtocolError) { return $true }
    if ($ex -is [Net.Sockets.SocketException]) { return $true }
    $ex = $ex.InnerException
  }
  return $false
}

# ---- 1. Location ----------------------------------------------------
function Get-WindowsLocation {
  Add-Type -AssemblyName System.Device
  $w = New-Object System.Device.Location.GeoCoordinateWatcher ([System.Device.Location.GeoPositionAccuracy]::Default)
  try {
    [void]$w.TryStart($false, [TimeSpan]::FromSeconds($LocateWaitSec))
    $deadline = (Get-Date).AddSeconds($LocateWaitSec)
    while ((Get-Date) -lt $deadline) {
      if ($w.Permission -eq 'Denied') { return 'denied' }
      $loc = $w.Position.Location
      if ($w.Status -eq 'Ready' -and -not $loc.IsUnknown) { return $loc }
      Start-Sleep -Milliseconds 300
    }
    if ($w.Permission -eq 'Denied' -or $w.Status -eq 'Disabled') { return 'denied' }
    return $null
  } finally {
    $w.Stop()
    $w.Dispose()
  }
}

try {
  $source = ''
  $latV = 0.0; $lonV = 0.0
  if ($Lat -ne '' -and $Lon -ne '') {
    $latV = [double]::Parse($Lat, $Inv); $lonV = [double]::Parse($Lon, $Inv)
    if ([math]::Abs($latV) -gt 90 -or [math]::Abs($lonV) -gt 180) { throw 'Bad WeatherLatitude / WeatherLongitude' }
    $source = 'fixed'
  } else {
    $loc = Get-WindowsLocation
    if ($loc -is [System.Device.Location.GeoCoordinate]) {
      $latV = $loc.Latitude; $lonV = $loc.Longitude; $source = 'windows'
    } elseif ($cache.Contains('location') -and $cache['location'].Count -ge 3) {
      $latV = [double]::Parse($cache['location'][1], $Inv); $lonV = [double]::Parse($cache['location'][2], $Inv)
      $source = 'cached'
    } elseif ($loc -eq 'denied') {
      Save-Cache 'nolocation' 'Windows location is off'
      exit 0
    } else {
      Save-Cache 'nolocation' 'No location from Windows'
      exit 0
    }
  }
  $latS = Num ([math]::Round($latV, 2)); $lonS = Num ([math]::Round($lonV, 2))
  $cache['location'] = @('location', $latS, $lonS, $source)

  # ---- 2. Place name ------------------------------------------------
  if (-not $NoPlace) {
    if ($Lang -notmatch '^[a-z]{2,3}$') { $Lang = (Get-Culture).TwoLetterISOLanguageName }
    $p = $cache['place']
    $same = $p -and $p.Count -ge 5 -and $p[1] -eq $latS -and $p[2] -eq $lonS -and $p[3] -eq $Lang
    if (-not $same) {
      try {
        $r = Invoke-RestMethod -Uri "$($PlaceUrl)?latitude=$latS&longitude=$lonS&localityLanguage=$Lang" -TimeoutSec $TimeoutSec
        $name = Clean $r.locality
        if (-not $name) { $name = Clean $r.city }
        $parts = @($r.locality, $r.city, $r.principalSubdivision) | ForEach-Object { Clean $_ } | Where-Object { $_ } | Select-Object -Unique
        $cache['place'] = @('place', $latS, $lonS, $Lang, $name, ($parts -join ', '))
      } catch {
        # The weather still works without a name; try again next run.
        if (Is-Offline $_) { throw }
      }
    }
  }

  # ---- 3. Weather ---------------------------------------------------
  $q = "latitude=$latS&longitude=$lonS" +
    '&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m' +
    '&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1'
  $w = Invoke-RestMethod -Uri "$($WeatherUrl)?$q" -TimeoutSec $TimeoutSec
  $cur = $w.current
  if ($null -eq $cur -or $null -eq $cur.temperature_2m) { throw 'No current weather in the reply' }
  $cache['current'] = @('current', (Num $cur.temperature_2m), (Num $cur.apparent_temperature),
    (Num $cur.relative_humidity_2m), ([int]$cur.weather_code).ToString($Inv), ([int]$cur.is_day).ToString($Inv),
    (Num $cur.wind_speed_10m))
  if ($w.daily -and $w.daily.temperature_2m_max) {
    $cache['today'] = @('today', (Num @($w.daily.temperature_2m_max)[0]), (Num @($w.daily.temperature_2m_min)[0]))
  }
  $cache['updated'] = @('updated', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
  Save-Cache 'ok' ''
} catch {
  if (Is-Offline $_) { Save-Cache 'offline' 'Offline' }
  else { Save-Cache 'error' $_.Exception.Message }
}
