# Upstream's in-app tests (Source\Tests.pas) through the test switch: each devcpp.exe given is
# copied beside the installed Dev-C++ (it needs its styles, languages and compilers there) and run
# as  <copy> -c <own config folder> -runtests <results> [-tests <names>]. The config starts as a
# copy of an existing one, so the run doesn't touch yours and skips the first-run dialogs.
#   .\run-app-tests.ps1 -Exe <devcpp.exe>[,<devcpp.exe>...] [-Tests editor,editorlist]
param(
  [Parameter(Mandatory)] [string[]]$Exe,
  [string]$Tests = 'editor,editorlist',
  [string]$Install = 'C:\Dev-Cpp',
  [string]$Config = "$env:APPDATA\Embarcadero\Dev-Cpp\devcpp64-test.ini",
  [int]$TimeoutSeconds = 300
)
$ErrorActionPreference = 'Continue'
$work = Join-Path $env:TEMP 'devcpp-apptests'
$failed = $false
$n = 0
foreach ($e in $Exe) {
  $n++
  $name = "devcpp-apptest$n"
  $copy = Join-Path $Install "$name.exe"
  $cfg  = Join-Path $work $name
  New-Item -ItemType Directory -Force $cfg | Out-Null
  Remove-Item "$cfg\*" -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item $e $copy -Force
  Copy-Item $Config (Join-Path $cfg "$name.ini")
  $codeIns = Join-Path (Split-Path $Config) 'codeinsertion.ini'
  if (Test-Path $codeIns) { Copy-Item $codeIns $cfg }
  $results = Join-Path $cfg 'results.txt'
  $p = Start-Process -FilePath $copy -ArgumentList '-c', "`"$cfg`"", '-runtests', "`"$results`"", '-tests', $Tests -PassThru
  if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
    $p.Refresh(); $title = $p.MainWindowTitle
    $p.Kill(); $p.WaitForExit(10000) | Out-Null
    "TIMEOUT after $TimeoutSeconds s: $e (window: '$title'; a dialog waiting?)"; $failed = $true
    Remove-Item $copy -Force -ErrorAction SilentlyContinue; continue
  }
  "== $e  (exit $($p.ExitCode))"
  if (Test-Path $results) { Get-Content $results } else { 'no results file'; $failed = $true }
  if ($p.ExitCode -ne 0) { $failed = $true }
  Remove-Item $copy -Force -ErrorAction SilentlyContinue
}
if ($failed) { exit 1 }
