<#
.SYNOPSIS
  Screenshots MyWindowWidget skins even when other windows cover the desktop.

.DESCRIPTION
  Temporarily sets each loaded skin to "stay topmost" (!ZPos 2), captures
  either one skin window or the whole primary screen (DPI-aware, physical
  pixels), then puts the skins back to "normal" (!ZPos 0).
  A black image means the screen is locked.

.EXAMPLE
  .\tools\dev\screenshot-skins.ps1 -Skin Calendar -Out $env:TEMP\cal.png
  .\tools\dev\screenshot-skins.ps1 -Out $env:TEMP\all.png
  .\tools\dev\screenshot-skins.ps1 -Skin Tasks -Out $env:TEMP\tasks.png
#>
param(
  [string]$Skin = '',
  [Parameter(Mandatory = $true)][string]$Out,
  [string[]]$Configs = @('Clock', 'System', 'Network', 'Music', 'Calendar', 'Settings', 'Tasks'),
  [string]$Suite = 'MyWindowWidget'
)

$rm = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
$code = @'
using System; using System.Text; using System.Runtime.InteropServices;
public class SkinShot {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  // Skin windows are titled with their .ini path.
  public static int[] Find(string tail) {
    int[] res = null;
    EnumWindows((h, l) => {
      var t = new StringBuilder(512); GetWindowText(h, t, 512);
      if (t.ToString().EndsWith(tail, StringComparison.OrdinalIgnoreCase)) {
        RECT r; GetWindowRect(h, out r); res = new int[] { r.L, r.T, r.R - r.L, r.B - r.T };
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
'@
Add-Type $code
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
[SkinShot]::SetProcessDPIAware() | Out-Null

foreach ($c in $Configs) { & $rm !ZPos 2 "$Suite\$c" }
Start-Sleep -Seconds 2
try {
  if ($Skin) {
    # Config X has X.ini.
    $ini = (Split-Path $Skin -Leaf) + '.ini'
    $r = [SkinShot]::Find("$Suite\$Skin\$ini")
    if (-not $r) { throw "Skin window not found: $Suite\$Skin" }
    $x, $y, $w, $h = ($r[0] - 10), ($r[1] - 10), ($r[2] + 20), ($r[3] + 20)
  } else {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x, $y, $w, $h = $b.X, $b.Y, $b.Width, $b.Height
  }
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "Saved $Out ($w x $h)"
} finally {
  foreach ($c in $Configs) { & $rm !ZPos 0 "$Suite\$c" }
}
