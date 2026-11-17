<#
.SYNOPSIS
  GPU usage sampler for the MyWindowWidget System skin.

.DESCRIPTION
  Why a script: the bundled UsageMonitor plugin (1.0.1.0, Rainmeter
  4.5.28) crashed Rainmeter on the development PC (Windows 11 build
  26300; unhandled NullReferenceException, 2026-11-17), even with
  Alias=CPU. Get-Counter works but costs ~1.4 s CPU per sample, so
  this reads the "GPU Engine" performance counters with .NET
  (PerformanceCounterCategory.ReadCategory, ~8 ms CPU per sample).

  The value is what Task Manager shows as GPU usage: per engine type
  (3D, Copy, VideoDecode, ...) the sum over all processes, then the
  busiest engine type, in percent (0-100).

  Started by System.lua through RunCommand (hidden window) and keeps
  running. Every -Interval seconds it writes @Resources\Cache\gpu.txt:
    <unix time> <percent with one decimal>     or
    <unix time> na                              (no GPU counters)
  It exits when:
    - another copy is already running (named mutex), or
    - @Resources\Cache\gpu.alive (written by System.lua every few
      seconds) is older than -AliveSeconds: the skin is gone, or
    - no Rainmeter process is left.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File GpuLoad.ps1 -Interval 2
#>
param(
  [ValidateRange(1, 60)][int]$Interval = 2,
  [ValidateRange(10, 600)][int]$AliveSeconds = 60
)

$ErrorActionPreference = 'Stop'
$CacheDir  = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Cache'))
$OutFile   = Join-Path $CacheDir 'gpu.txt'
$AliveFile = Join-Path $CacheDir 'gpu.alive'

$mutex = New-Object Threading.Mutex($false, 'Local\MyWindowWidget.GpuLoad')
if (-not $mutex.WaitOne(0)) { exit 0 }

function Write-Value([string]$v) {
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $tmp = "$OutFile.tmp"
  [IO.File]::WriteAllText($tmp, "$now $v")
  Move-Item -LiteralPath $tmp -Destination $OutFile -Force
}

function Alive {
  if (-not (Test-Path -LiteralPath $AliveFile)) { return $false }
  $age = ((Get-Date) - (Get-Item -LiteralPath $AliveFile).LastWriteTime).TotalSeconds
  if ($age -gt $AliveSeconds) { return $false }
  return @([Diagnostics.Process]::GetProcessesByName('Rainmeter')).Count -gt 0
}

try {
  if (-not [Diagnostics.PerformanceCounterCategory]::Exists('GPU Engine')) {
    Write-Value 'na'
    exit 0
  }

  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
public static class MwwGpuLoad {
  static readonly PerformanceCounterCategory Cat = new PerformanceCounterCategory("GPU Engine");
  static Dictionary<string, CounterSample> prev;
  // Busiest engine type; per engine type the sum over processes.
  // The first call only stores samples and returns -1.
  public static double Sample() {
    InstanceDataCollection d = Cat.ReadCategory()["Utilization Percentage"];
    var cur = new Dictionary<string, CounterSample>(d.Count);
    var byEngine = new Dictionary<string, double>();
    foreach (InstanceData i in d.Values) {
      cur[i.InstanceName] = i.Sample;
      CounterSample p;
      if (prev != null && prev.TryGetValue(i.InstanceName, out p)) {
        int at = i.InstanceName.LastIndexOf("engtype_", StringComparison.Ordinal);
        string engine = at >= 0 ? i.InstanceName.Substring(at + 8) : "";
        double sum;
        byEngine.TryGetValue(engine, out sum);
        byEngine[engine] = sum + CounterSample.Calculate(p, i.Sample);
      }
    }
    bool first = prev == null;
    prev = cur;
    if (first) return -1;
    double max = 0;
    foreach (double v in byEngine.Values) if (v > max) max = v;
    return Math.Max(0, Math.Min(100, max));
  }
}
'@

  [void][MwwGpuLoad]::Sample()
  while (Alive) {
    Start-Sleep -Seconds $Interval
    $v = [MwwGpuLoad]::Sample()
    Write-Value $v.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
  }
} catch {
  # Counters unreadable (permissions, broken perf registry): the skin
  # shows "n/a" instead of a stale value.
  try { Write-Value 'na' } catch { }
} finally {
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
