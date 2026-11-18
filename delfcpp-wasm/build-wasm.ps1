# Builds ParseCorpus.wasm (the class browser's chain) with FPC's wasm32-wasip1 compiler from one
# version of Dev-C++'s units, then runs upstream's parser corpus through it in Node and compares
# with delfcpp-tests' golden files (Windows, dcc32, upstream master).
#   .\build-wasm.ps1 -Version original|dev64|delf
# The compiler: Delf's experiments\wasm\fpc-331-18863\setup.ps1, built in $Work.
param(
  [ValidateSet('original', 'dev64', 'delf')] [string]$Version = 'dev64',
  [string]$Work = "$env:LOCALAPPDATA\delf-wasm",
  [string]$Fpc  = 'D:\fpc\3.3.1'
)
$ErrorActionPreference = 'Continue'
$Here  = $PSScriptRoot
$Root  = (Resolve-Path "$Here\..\..").Path            # holds Dev-Cpp and Dev-Cpp-dev64
$Delf  = "$Root\Dev-Cpp"; $Dev64 = "$Root\Dev-Cpp-dev64"
$PPC   = "$Work\fpcsrc\compiler\ppcrosswasm32.exe"
$S     = "$Fpc\fpcsrc"
$Units = 'cbutils', 'CharUtils', 'StatementList', 'IntList', 'CppTokenizer', 'CppPreprocessor', 'CppParser'
$Paths = @{ CharUtils = 'Source/CharUtils.pas' }
$Out   = "$Here\out\$Version"
New-Item -ItemType Directory -Force "$Out\src", "$Out\units" | Out-Null
Remove-Item "$Out\src\*", "$Out\units\*" -Force -ErrorAction SilentlyContinue

foreach ($u in $Units) {
  $rel = if ($Paths[$u]) { $Paths[$u] } else { "Source/VCL/ClassBrowsing/$u.pas" }
  # master spells some of these names in other cases (CBUtils.pas): find its own spelling
  $mrel = (git -C $Dev64 ls-tree -r --name-only master | Where-Object { $_ -ieq $rel } | Select-Object -First 1)
  $text = switch ($Version) {
    'original' { git -C $Dev64 show "master:$mrel" | Out-String }
    'dev64'    { Get-Content -Raw "$Dev64\$rel" }
    'delf'     { Get-Content -Raw "$Delf\$rel" }
  }
  # Delphi's unit scopes to FPC's plain names; the uses of Windows/VCL units go to stand-ins
  $text = $text -replace '\bSystem\.AnsiStrings\b', 'AnsiStrings' -replace '\bSystem\.Character\b', 'Character' `
                -replace '\bSystem\.SysUtils\b', 'SysUtils'
  $text = $text -replace '(?m)^(\s*)(Dialogs|ComCtrls|Forms),', '$1' -replace ',\s*(Dialogs|ComCtrls|Forms)\b', ''
  # the uses clauses are guarded {$IFDEF MSWINDOWS} (upstream: WIN32), {$IFDEF LINUX} for Kylix;
  # WASI is neither, so the Windows branch is made unconditional (nothing else is guarded)
  $text = $text -replace '\{\$IFDEF (MSWINDOWS|WIN32)\}', '{$IFNDEF DELFCPP_NEVER}'
  # Delphi's intrinsic ReturnAddress (where an exception says it was raised) is FPC's get_caller_addr
  $text = $text -replace '\bat ReturnAddress\b', 'at get_caller_addr(get_frame)'
  # CharUtils lists '!' twice in DefOperatorChars: dcc accepts it, FPC calls it an error
  $text = $text -replace "'<', '\^', '!'\]", "'<', '^']"
  # FPC's RTL is AnsiString-based: its ExtractStrings takes PAnsiChar. These split a macro's
  # arguments (C identifiers, ASCII), so the WASM copy passes them as AnsiString (lossy past ASCII)
  $text = $text -replace 'PChar\((FunctionDefine\^\.Args|ArgValueString)\), Arg', 'PAnsiChar(AnsiString($1)), Arg'
  # delfc's output (the delf version): FPC forbids raise in a noreturn routine (dcc uses the
  # directive to drop warnings only), and has no inline variables: IntList.ExchangeItems' Temp
  $text = $text -replace ';\s*noreturn;', ';'
  $text = $text -replace '(?s)(procedure TIntList\.ExchangeItems\(Index1, Index2: Integer\);\r?\n)begin(\r?\n\s*)var Temp :=',
                         "`$1var Temp: TIntItem;`r`nbegin`$2Temp :="
  # CharUtils' two inline loop variables (FPC has none), hoisted with their types
  $text = $text -replace '(?s)(class operator TSetOfChar\.In\([^)]*\): Boolean;\r?\n)begin(\r?\n\s*)for var SetChar in',
                         "`$1var SetChar: Char;`r`nbegin`$2for SetChar in"
  $text = $text -replace '(?s)(constructor TSetOfChar\.New\([^)]*\);\r?\n)begin(\r?\n\s*FSet := \[\];\r?\n\s*)for var AChar in',
                         "`$1var AChar: AnsiChar;`r`nbegin`$2for AChar in"
  # FPC's mode, first thing in the unit
  $text = "{`$MODE DELPHIUNICODE}`r`n" + $text
  Set-Content -Path "$Out\src\$u.pas" -Value $text -Encoding UTF8 -NoNewline
}
Copy-Item "$Here\ParseCorpus.dpr" "$Out\src\"

$fu = @("-Fu$Work\fpcsrc\rtl\units\wasm32-wasip1", "-Fu$Here\shim", "-Fu$Out\src",
        "-Fu$S\packages\rtl-objpas\src\inc", "-Fi$S\packages\rtl-objpas\src\inc",
        "-Fu$S\packages\fcl-base\src", "-Fi$S\packages\fcl-base\src",
        "-Fu$S\packages\rtl-extra\src\inc", "-Fu$S\packages\rtl-unicode\src\inc")
$env:PATH = "$Work\bin;$env:PATH"   # wasm-ld
Set-Location "$Out\src"               # FPC looks in the current folder first
& $PPC -Twasip1 -Pwasm32 -Mdelphiunicode "-FU$Out\units" @fu "-o$Out\ParseCorpus.wasm" "$Out\src\ParseCorpus.dpr" *> "$Out\build.log"
$errs = Get-Content "$Out\build.log" | Where-Object { $_ -match '(Error|Fatal):' }
if (-not (Test-Path "$Out\ParseCorpus.wasm")) {
  "BUILD FAILED ($Version):"; $errs | Select-Object -First 12; exit 1
}
"built $Out\ParseCorpus.wasm ({0:N0} bytes)" -f (Get-Item "$Out\ParseCorpus.wasm").Length
node --no-warnings "$Here\run-corpus.mjs" "$Out\ParseCorpus.wasm" "$Dev64\Source\Tests\Parser" "$Delf\delfcpp-tests\golden"
