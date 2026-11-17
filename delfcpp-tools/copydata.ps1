param([int] $ProcessId, [string] $Text, [switch] $NoTerminator)
# Sends Dev-C++'s WM_COPYDATA (dwData 12345, UTF-16 text) to a process's main window, as a second instance would.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CopyData5 {
  [StructLayout(LayoutKind.Sequential)] public struct COPYDATASTRUCT { public IntPtr dwData; public int cbData; public IntPtr lpData; }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, ref COPYDATASTRUCT l);
}
"@
$hwnd = (Get-Process -Id $ProcessId).MainWindowHandle
$bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)
if (-not $NoTerminator) { $bytes = [byte[]]($bytes + [byte[]](0, 0)) }
$mem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length + 64)
# fill what follows the text with 'A's, so a reader that runs past the end sees junk, not zeros
[System.Runtime.InteropServices.Marshal]::Copy([byte[]](,65 * ($bytes.Length + 64)), 0, $mem, $bytes.Length + 64)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $mem, $bytes.Length)
$cds = New-Object CopyData5+COPYDATASTRUCT
$cds.dwData = [IntPtr] 12345; $cds.cbData = $bytes.Length; $cds.lpData = $mem
[CopyData5]::SendMessage($hwnd, 0x4A, [IntPtr]::Zero, [ref] $cds) | Out-Null
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($mem)
"sent $($bytes.Length) bytes" + $(if ($NoTerminator) { " (no terminator)" } else { "" })
