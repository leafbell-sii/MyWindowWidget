<#
.SYNOPSIS
  Prints Rainmeter's log (About > Log) without enabling file logging.

.DESCRIPTION
  Opens the About dialog (!About) and reads its log list view from
  the Rainmeter process (LVM_GETITEMTEXTW). UI Automation does not
  expose these rows. Newest entries come first:
    <type> | <time> | <source> | <message>

  Works with any Rainmeter UI language: the dialog is found by its
  class (#32770) and owner process, not by its translated title.

.EXAMPLE
  # Errors and warnings since 14:30:00
  .\tools\dev\read-rainmeter-log.ps1 -Since 14:30:00 | Select-String -NotMatch 'Refreshing skin'
#>
param([string]$Since = '00:00:00', [int]$Max = 200)

$rm = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
Start-Process $rm -ArgumentList '!About'
Start-Sleep -Seconds 2

$code = @'
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class RmLog {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint a, bool i, uint pid);
  [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, uint s, uint t, uint pr);
  [DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, uint s, uint t);
  [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, int s, out IntPtr w);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, int s, out IntPtr r);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

  static IntPtr FindLogList(uint rmPid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid != rmPid || !IsWindowVisible(h)) return true;
      var cls = new StringBuilder(64); GetClassName(h, cls, 64);
      if (cls.ToString() != "#32770") return true;
      IntPtr page = FindWindowEx(h, IntPtr.Zero, "#32770", null);
      IntPtr lv = FindWindowEx(page, IntPtr.Zero, "SysListView32", null);
      if (lv != IntPtr.Zero) { found = lv; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static List<string> Read(uint rmPid, int max) {
    var res = new List<string>();
    IntPtr lv = FindLogList(rmPid);
    if (lv == IntPtr.Zero) return res;
    int n = (int)SendMessage(lv, 0x1004, IntPtr.Zero, IntPtr.Zero);          // LVM_GETITEMCOUNT
    IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020, false, rmPid);
    IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, 0x2000, 0x1000, 0x04);
    IntPtr w;
    for (int i = 0; i < Math.Min(n, max); i++) {
      var sb = new StringBuilder();
      for (int sub = 0; sub < 4; sub++) {
        byte[] item = new byte[88];                                          // LVITEMW (x64)
        BitConverter.GetBytes(sub).CopyTo(item, 8);                          // iSubItem
        BitConverter.GetBytes((long)mem + 0x100).CopyTo(item, 24);           // pszText
        BitConverter.GetBytes(1024).CopyTo(item, 32);                        // cchTextMax
        WriteProcessMemory(hp, mem, item, item.Length, out w);
        int len = (int)SendMessage(lv, 0x1073, (IntPtr)i, mem);              // LVM_GETITEMTEXTW
        byte[] buf = new byte[2048];
        ReadProcessMemory(hp, mem + 0x100, buf, buf.Length, out w);
        sb.Append(Encoding.Unicode.GetString(buf, 0, Math.Max(0, len) * 2));
        if (sub < 3) sb.Append(" | ");
      }
      res.Add(sb.ToString());
    }
    VirtualFreeEx(hp, mem, 0, 0x8000); CloseHandle(hp);
    return res;
  }
}
'@
Add-Type $code
$proc = Get-Process Rainmeter -ErrorAction Stop | Select-Object -First 1
[RmLog]::Read([uint32]$proc.Id, $Max) | Where-Object { ($_ -split ' \| ')[1] -ge $Since }
