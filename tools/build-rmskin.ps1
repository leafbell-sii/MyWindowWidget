<#
.SYNOPSIS
  Builds dist\Umber_<Version>.rmskin from the Umber folder.

.DESCRIPTION
  Produces the same format as Rainmeter's own Skin Packager
  (Library/DialogPackage.cpp in rainmeter/rainmeter):

    RMSKIN.ini                    [rmskin] options
    RMSKIN.bmp                    400x60 header shown by the installer
    Skins/Umber/...               the suite
    Plugins/32bit|64bit/*.dll     WebNowPlaying (from vendor/)

  followed by a 16-byte footer: int64 zip size, 1 flag byte (0),
  "RMSKIN\0". The installer refuses packages without it.

  Left out of the package: the real Secrets.inc (replaced by the
  empty template), downloaded calendars / caches, .gitignore and
  placeholder-only folders.

  Do NOT install the result on a machine where Skins\Umber is a
  junction to this repository: the installer moves the existing
  folder (the junction) to Skins\@Backup.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\build-rmskin.ps1 -Version 0.1.0
#>
param(
  [string]$Version = '0.1.0',
  [string]$Author = 'siidi',
  [string]$MinimumRainmeter = '4.5.0',
  [string]$MinimumWindows = '10.0'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

$root    = Split-Path -Parent $PSScriptRoot
$skinDir = Join-Path $root 'Umber'
$vendor  = Join-Path $root 'vendor\WebNowPlaying'
$distDir = Join-Path $root 'dist'
$outFile = Join-Path $distDir ("Umber_{0}.rmskin" -f $Version)

foreach ($p in @($skinDir, "$vendor\64bit\WebNowPlaying.dll", "$vendor\32bit\WebNowPlaying.dll",
                 "$skinDir\@Resources\Secrets.example.inc")) {
  if (-not (Test-Path $p)) { throw "Missing: $p" }
}
New-Item -ItemType Directory -Force $distDir | Out-Null

# ---- Which skin files go in ---------------------------------------
function Test-Excluded([string]$rel) {
  $r = $rel -replace '\\', '/'
  if ($r -eq '.gitignore') { return $true }
  if ($r -eq '@Resources/Secrets.inc') { return $true }          # real secrets
  if ($r -eq '@Resources/Secrets.example.inc') { return $true }  # shipped as Secrets.inc
  if ($r -like '*.ics') { return $true }
  if ($r -like '@Resources/Cache/*' -and $r -ne '@Resources/Cache/.keep') { return $true }
  if ($r -like '*/DownloadFile/*') { return $true }
  # Folders that only hold a placeholder.
  if ($r -eq '@Resources/Fonts/.keep' -or $r -eq '@Resources/Images/.keep') { return $true }
  return $false
}

$entries = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $skinDir -Recurse -File -Force | ForEach-Object {
  $rel = $_.FullName.Substring($skinDir.Length + 1)
  if (-not (Test-Excluded $rel)) {
    $entries.Add([pscustomobject]@{ Zip = 'Skins/Umber/' + ($rel -replace '\\', '/'); Path = $_.FullName; Bytes = $null })
  }
}
# Empty secrets template, preserved on upgrade through VariableFiles.
$entries.Add([pscustomobject]@{ Zip = 'Skins/Umber/@Resources/Secrets.inc'; Path = "$skinDir\@Resources\Secrets.example.inc"; Bytes = $null })

foreach ($arch in '32bit', '64bit') {
  $entries.Add([pscustomobject]@{ Zip = "Plugins/$arch/WebNowPlaying.dll"; Path = "$vendor\$arch\WebNowPlaying.dll"; Bytes = $null })
}
# MIT requires the notice to travel with the DLL.
$entries.Add([pscustomobject]@{ Zip = 'Skins/Umber/@Resources/Licenses/WebNowPlaying.txt'; Path = "$vendor\LICENSE"; Bytes = $null })

# ---- RMSKIN.ini ------------------------------------------------------
# VariableFiles: user values in these files survive reinstalls
# (iCal URLs, Use24h, WeekStart, ...). Paths start at Skins\.
$ini = @"
[rmskin]
Name=Umber
Author=$Author
Version=$Version
LoadType=Skin
Load=Umber\Clock\Clock.ini
VariableFiles=Umber\@Resources\Secrets.inc | Umber\@Resources\Variables.inc
MinimumRainmeter=$MinimumRainmeter
MinimumWindows=$MinimumWindows
"@
$entries.Add([pscustomobject]@{ Zip = 'RMSKIN.ini'; Path = $null; Bytes = [Text.Encoding]::ASCII.GetBytes(($ini -replace "`r?`n", "`r`n") + "`r`n") })

# ---- RMSKIN.bmp (400x60 header) --------------------------------------
$bmp = New-Object System.Drawing.Bitmap 400, 60, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(32, 22, 17))
$accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(214, 154, 96))
$cream  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(242, 232, 220))
$muted  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(190, 170, 150))
$g.FillRectangle($accent, 0, 0, 6, 60)
$g.DrawString('Umber', (New-Object System.Drawing.Font 'Segoe UI Semibold', 20), $cream, 18, 8)
$g.DrawString("Clock  System  Network  Music  Calendar   v$Version", (New-Object System.Drawing.Font 'Segoe UI', 8.5), $muted, 21, 38)
$g.Dispose()
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Bmp)
$bmp.Dispose()
$entries.Add([pscustomobject]@{ Zip = 'RMSKIN.bmp'; Path = $null; Bytes = $ms.ToArray() })

# ---- Zip ---------------------------------------------------------------
if (Test-Path $outFile) { Remove-Item $outFile -Force }
$fs = [System.IO.File]::Open($outFile, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
# Installer reads RMSKIN.ini first; keep it (and the header) at the top.
$ordered = @($entries | Where-Object { $_.Zip -like 'RMSKIN.*' }) + @($entries | Where-Object { $_.Zip -notlike 'RMSKIN.*' } | Sort-Object Zip)
foreach ($e in $ordered) {
  $entry = $zip.CreateEntry($e.Zip, [System.IO.Compression.CompressionLevel]::Optimal)
  $out = $entry.Open()
  # (An empty byte[] becomes $null in PowerShell; empty files just get no data.)
  $data = if ($e.Bytes) { $e.Bytes } else { [System.IO.File]::ReadAllBytes($e.Path) }
  if ($data) { $out.Write($data, 0, $data.Length) }
  $out.Dispose()
}
$zip.Dispose()
$fs.Dispose()

# ---- Footer ------------------------------------------------------------
$zipSize = (Get-Item $outFile).Length
$footer = New-Object byte[] 16
[BitConverter]::GetBytes([int64]$zipSize).CopyTo($footer, 0)
$footer[8] = 0
[Text.Encoding]::ASCII.GetBytes('RMSKIN').CopyTo($footer, 9)   # byte 15 stays 0
$fs = [System.IO.File]::Open($outFile, [System.IO.FileMode]::Append)
$fs.Write($footer, 0, 16)
$fs.Dispose()

Write-Host ("Built {0} ({1:N0} bytes, {2} files)" -f $outFile, (Get-Item $outFile).Length, $ordered.Count)
