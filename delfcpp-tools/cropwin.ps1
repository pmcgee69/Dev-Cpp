param([string] $Out, [int] $ProcessId, [int] $W = 1600, [int] $H = 260)
# Crops the top-left of a process's main window, in physical pixels, at full resolution.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win3 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
[Win3]::SetProcessDPIAware() | Out-Null
$hwnd = (Get-Process -Id $ProcessId).MainWindowHandle
[Win3]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 600
$r = New-Object Win3+RECT
[Win3]::GetWindowRect($hwnd, [ref] $r) | Out-Null
$W = [Math]::Min($W, $r.R - $r.L); $H = [Math]::Min($H, $r.B - $r.T)
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"window at $($r.L),$($r.T) size $($r.R-$r.L)x$($r.B-$r.T); saved ${W}x${H}"
