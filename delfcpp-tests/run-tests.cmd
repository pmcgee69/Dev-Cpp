@echo off
rem DelfCpp's tests: the same tests against three versions of the units, on Win32 and Win64.
rem   original : the units before any DelfCpp fix (git ref ORIGINAL_REF, default dcef9cf,
rem              the Win64 port), taken out of the repository into out\original-src
rem   dev64    : the dev64 checkout's plain Delphi
rem   delf     : the delf-units checkout's units (delfc's .pas output of each .delf)
rem The two checkouts sit side by side: ..\..\Dev-Cpp (delf-units) and ..\..\Dev-Cpp-dev64.
rem Usage: run-tests.cmd [original|dev64|delf|all]   (default all). Exit 1 if a run failed;
rem the original is expected to fail its Regression tests.
setlocal enabledelayedexpansion
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
for %%R in ("%HERE%\..\..") do set "ROOT=%%~fR"
set "DELF=%ROOT%\Dev-Cpp"
set "DEV64=%ROOT%\Dev-Cpp-dev64"
if not defined ORIGINAL_REF set ORIGINAL_REF=dcef9cf
set "OUT=%HERE%\out"
set WHICH=%1
if "%WHICH%"=="" set WHICH=all

rem The units under test, as paths under Source (the original's are taken from git)
set UNITS=VCL/ClassBrowsing/CppTokenizer.pas

rem Every other unit comes from the version's own Source, as devcpp.dproj finds them
set "SUB=VCL\ClassBrowsing;VCL\SVGIconImageList\Svg;VCL\SVGIconImageList\Source;VCL\devFileMonitor;VCL\devShortcuts;VCL\CompOptionsList;VCL\SynEdit\Source;VCL\vcl-styles-utils\Common;VCL\DDetours\Source"

if not exist "%OUT%\original-src" mkdir "%OUT%\original-src"
for %%U in (%UNITS%) do (
  git -C "%DEV64%" show %ORIGINAL_REF%:Source/%%U > "%OUT%\original-src\%%~nxU"
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
if "%V%"=="original" (set "SRC=%DEV64%\Source" & set "FIRST=%OUT%\original-src;")
if "%V%"=="dev64" (set "SRC=%DEV64%\Source" & set "FIRST=")
if "%V%"=="delf" (set "SRC=%DELF%\Source" & set "FIRST=")
set "UPATH=%FIRST%%SRC%"
for %%S in (%SUB%) do set "UPATH=!UPATH!;%SRC%\%%S"
for %%P in (32 64) do (
  set "BIN=%OUT%\%V%-win%%P"
  if not exist "!BIN!" mkdir "!BIN!"
  if %%P==32 (set "LIB=%BDS%\lib\win32\release") else (set "LIB=%BDS%\lib\win64\release")
  "%BDS%\bin\dcc%%P.exe" -Q -B -NSSystem;Winapi;Vcl;Vcl.Imaging;System.Win "-U!UPATH!;!LIB!" "-E!BIN!" "-NU!BIN!" "%HERE%\DelfCppTests.dpr" > "!BIN!\build.log" 2>&1
  if errorlevel 1 (
    echo === %V% Win%%P: BUILD FAILED, see !BIN!\build.log
    set "FAILED=1"
  ) else (
    "!BIN!\DelfCppTests.exe" --exitbehavior:Continue > "!BIN!\results.txt" 2>&1
    rem the exit code first: in a .cmd file, set resets the error level
    set "RC=!errorlevel!"
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
    echo === %V% Win%%P: !R!  !LAST!
    set LAST=
  )
)
exit /b 0
