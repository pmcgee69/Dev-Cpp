param([int] $ProcessId, [int] $X, [int] $Y)
# Left-clicks at (X, Y) inside a process's main window, in physical pixels from its top-left.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Click4 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
}
"@
[Click4]::SetProcessDPIAware() | Out-Null
$hwnd = (Get-Process -Id $ProcessId).MainWindowHandle
[Click4]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400
$r = New-Object Click4+RECT
[Click4]::GetWindowRect($hwnd, [ref] $r) | Out-Null
[Click4]::SetCursorPos($r.L + $X, $r.T + $Y) | Out-Null
Start-Sleep -Milliseconds 150
[Click4]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
[Click4]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
"clicked at $($r.L + $X),$($r.T + $Y)"
