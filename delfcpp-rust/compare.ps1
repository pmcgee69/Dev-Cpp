# The Rust port of CppTokenizer against the Delphi one, token for token.
#   .\compare.ps1 [-Corpus parser|gcc|all] [-Wasm]
# Builds TokDump.dpr with dcc32 against dev64's CppTokenizer and the Delf one (delfcpp-units),
# and the Rust tokdump natively (and for wasm32-wasip1 with -Wasm, run by Node's WASI). All read
# the same files and write the same format; the dumps must be identical.
param(
  [ValidateSet('parser', 'gcc', 'all')] [string]$Corpus = 'all',
  [switch]$Wasm,
  [string]$Gcc = 'D:\DCPP\xDev-Cpp\TDM-GCC-64'
)
$ErrorActionPreference = 'Continue'   # PS 5.1 makes a native program's stderr an error under Stop
$Here  = $PSScriptRoot
$Root  = (Resolve-Path "$Here\..\..").Path
$Delf  = "$Root\Dev-Cpp-delf"; $Dev64 = "$Root\Dev-Cpp-dev64"
$Out   = "$Here\out"
New-Item -ItemType Directory -Force $Out | Out-Null

# The corpora: upstream's parser tests, and the GCC headers (each list relative to its root)
$sets = @()
if ($Corpus -in 'parser', 'all') { $sets += , @('parser', "$Dev64\Source\Tests\Parser") }
if ($Corpus -in 'gcc', 'all')    { $sets += , @('gcc', $Gcc) }
foreach ($s in $sets) {
  $base = (Resolve-Path $s[1]).Path
  Get-ChildItem -Recurse -File $base | Where-Object { $_.Extension -in '', '.h', '.hpp', '.hxx', '.tcc', '.c', '.cpp', '.cc', '.inl' } |
    ForEach-Object { $_.FullName.Substring($base.Length + 1).Replace('\', '/') } | Sort-Object |
    Set-Content -Encoding ASCII "$Out\$($s[0]).list"
}

# Delphi: one TokDump per version
$bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$ns  = 'Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win'
$dumpers = @{}
foreach ($v in @(@('dev64', $Dev64), @('delf', $Delf))) {
  $bin = "$Out\delphi-$($v[0])"; New-Item -ItemType Directory -Force $bin | Out-Null
  $src = $v[1] + '\Source'
  & "$bds\bin\dcc32.exe" -Q -B "-NS$ns" "-U$src\VCL\ClassBrowsing;$src;$bds\lib\win32\release" "-E$bin" "-NU$bin" "$Here\TokDump.dpr" *> "$bin\build.log"
  if (-not (Test-Path "$bin\TokDump.exe")) { "dcc32 failed ($($v[0])):"; Get-Content "$bin\build.log" | Select-String 'Error|Fatal'; exit 1 }
  $dumpers[$v[0]] = "$bin\TokDump.exe"
}

# Rust: native, and WASI
Push-Location $Here
cargo build --release -q 2>&1 | Out-Host
if ($Wasm) { cargo build --release -q --target wasm32-wasip1 2>&1 | Out-Host }
Pop-Location
$rust = "$Here\target\release\tokdump.exe"

$failed = $false
foreach ($s in $sets) {
  $name = $s[0]; $base = (Resolve-Path $s[1]).Path; $list = "$Out\$name.list"
  $n = (Get-Content $list).Count
  $runs = [ordered]@{}
  foreach ($k in $dumpers.Keys | Sort-Object) {
    $t = Measure-Command { & $dumpers[$k] $base $list "$Out\$name.delphi-$k.txt" 2>$null }
    $runs["delphi-$k"] = $t.TotalSeconds
  }
  $t = Measure-Command { & $rust $base $list "$Out\$name.rust.txt" 2>$null }; $runs['rust'] = $t.TotalSeconds
  if ($Wasm) {
    $t = Measure-Command { node --no-warnings "$Here\run-wasi.mjs" "$Here\target\wasm32-wasip1\release\tokdump.wasm" $base $Out $name }
    $runs['wasm'] = $t.TotalSeconds
  }
  $ref = "$Out\$name.delphi-dev64.txt"
  $refHash = (Get-FileHash $ref).Hash
  $toks = (Select-String -Path $ref -Pattern '^===|^!error' -NotMatch).Count
  "${name}: $n files, $toks tokens (dev64)"
  foreach ($k in $runs.Keys) {
    $f = "$Out\$name.$k.txt"
    $same = (Get-FileHash $f).Hash -eq $refHash
    if (-not $same) { $failed = $true }
    "  {0,-14} {1,6:N2} s  {2}" -f $k, $runs[$k], $(if ($same) { 'identical' } else { 'DIFFERS' })
  }
}
if ($failed) { exit 1 }
