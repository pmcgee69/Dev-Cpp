@echo off
rem DelfCpp's tests: the same tests against three versions of the units, on Win32 and Win64.
rem   original : the units before any DelfCpp fix, taken out of the repository into
rem              out\original-src-win32|64. Win32: upstream as it is (ORIGINAL_REF32, default
rem              master). Win64: upstream doesn't compile for Win64, so upstream plus only the
rem              Win64 port's changes (ORIGINAL_REF64, default dcef9cf).
rem   dev64    : the dev64 checkout's plain Delphi
rem   delf     : the delfcpp-units checkout's units (delfc's .pas output of each .delf)
rem The two checkouts sit side by side: ..\..\Dev-Cpp-delf (delfcpp-units) and ..\..\Dev-Cpp-dev64.
rem Usage: run-tests.cmd [original|dev64|delf|all]   (default all). Exit 1 if a run failed;
rem the original is expected to fail its Regression tests.
setlocal enabledelayedexpansion
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
for %%R in ("%HERE%\..\..") do set "ROOT=%%~fR"
set "DELF=%ROOT%\Dev-Cpp-delf"
set "DEV64=%ROOT%\Dev-Cpp-dev64"
if not defined ORIGINAL_REF32 set ORIGINAL_REF32=master
if not defined ORIGINAL_REF64 set ORIGINAL_REF64=dcef9cf
set "OUT=%HERE%\out"
set WHICH=%1
if "%WHICH%"=="" set WHICH=all

rem The units under test, as paths under Source (the original's are taken from git)
set UNITS=VCL/ClassBrowsing/CppTokenizer.pas VCL/ClassBrowsing/IntList.pas Instances.pas Utils.pas EditorList.pas VCL/ClassBrowsing/StatementList.pas

rem Every other unit comes from the version's own Source, as devcpp.dproj finds them
set "SUB=VCL\ClassBrowsing;VCL\SVGIconImageList\Svg;VCL\SVGIconImageList\Source;VCL\devFileMonitor;VCL\devShortcuts;VCL\CompOptionsList;VCL\SynEdit\Source;VCL\vcl-styles-utils\Common;VCL\DDetours\Source"

for %%P in (32 64) do (
  if not exist "%OUT%\original-src-win%%P" mkdir "%OUT%\original-src-win%%P"
  for %%U in (%UNITS%) do (
    git -C "%DEV64%" show !ORIGINAL_REF%%P!:Source/%%U > "%OUT%\original-src-win%%P\%%~nxU"
  )
)

set FAILED=0
for %%V in (original dev64 delf) do (
  if "%WHICH%"=="all" (call :run %%V) else if "%WHICH%"=="%%V" (call :run %%V)
)
echo.
if "!FAILED!"=="1" (
  echo A fixed version failed or did not build.
  exit /b 1
)
echo The fixed versions passed.
exit /b 0

:run
set V=%1
set "SRC=%DEV64%\Source"
if "%V%"=="delf" set "SRC=%DELF%\Source"
set "BASE=%SRC%"
for %%S in (%SUB%) do set "BASE=!BASE!;%SRC%\%%S"
for %%P in (32 64) do (
  set "UPATH=!BASE!"
  if "%V%"=="original" set "UPATH=%OUT%\original-src-win%%P;!BASE!"
  set "BIN=%OUT%\%V%-win%%P"
  if not exist "!BIN!" mkdir "!BIN!"
  if %%P==32 (set "LIB=%BDS%\lib\win32\release") else (set "LIB=%BDS%\lib\win64\release")
  "%BDS%\bin\dcc%%P.exe" -Q -B -NSVcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win "-U!UPATH!;!LIB!" "-E!BIN!" "-NU!BIN!" "%HERE%\DelfCppTests.dpr" > "!BIN!\build.log" 2>&1
  if errorlevel 1 (
    echo === %V% Win%%P: BUILD FAILED, see !BIN!\build.log
    set "FAILED=1"
  ) else (
    set "EXCL="
    if "%V%"=="original" set "EXCL=--exclude:CrashesOriginal"
    "!BIN!\DelfCppTests.exe" --exitbehavior:Continue !EXCL! > "!BIN!\results.txt" 2>&1
    rem the exit code first: in a .cmd file, set resets the error level
    set "RC=!errorlevel!"
    if "%V%"=="original" (
      rem the tests that kill the original, run on their own: a crash here is the bug they pin
      "!BIN!\DelfCppTests.exe" --exitbehavior:Continue --include:CrashesOriginal > "!BIN!\results-crashes.txt" 2>&1
      set "CRC=!errorlevel!"
      rem a crash is an NTSTATUS exit code, negative here; which one depends on what the overrun hits
      set "CRASH="
      if "!CRC!"=="-1073741819" set "CRASH=access violation (0xC0000005)"
      if "!CRC!"=="-1073741571" set "CRASH=stack overflow (0xC00000FD)"
      if "!CRC!"=="-1073740791" set "CRASH=stack buffer overrun (0xC0000409)"
      if not defined CRASH if !CRC! LSS 0 set "CRASH=exit code !CRC!"
      if defined CRASH (
        echo === %V% Win%%P: the CrashesOriginal tests crash the original, as expected: !CRASH!
      ) else (
        echo === %V% Win%%P: the CrashesOriginal tests did not crash the original, exit code !CRC!
      )
    )
    set "R=passed"
    if not "!RC!"=="0" (
      if "%V%"=="original" (
        set "R=failed, as expected: the bugs the Regression tests pin"
      ) else (
        set "R=FAILED"
        set "FAILED=1"
      )
    )
    for /f "tokens=*" %%L in ('findstr /r /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "!BIN!\results.txt"') do set "LAST=!LAST! %%L"
    rem no summary: the test program itself died (a stack overrun, say); the tests after it didn't run
    if not defined LAST set "LAST=CRASHED: the test program died, exit code !RC!; see !BIN!\results.txt"
    echo === %V% Win%%P: !R!  !LAST!
    set LAST=
  )
)
exit /b 0
