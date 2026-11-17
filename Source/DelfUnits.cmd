@echo off
rem Dev-C++'s Delf units: delfc writes each .delf file's Delphi (.pas) beside it.
rem devcpp.dproj runs this before every build. It needs Delf's compiler, delfc: set DELF_POC to
rem Delf's poc folder, where "python -m delfc" runs. Without DELF_POC nothing is done, and the
rem committed .pas files (delfc's last output) are built as they are. Edit the .delf, not the .pas:
rem delfc replaces only a .pas it wrote itself, and stops at one that was edited since.
setlocal enabledelayedexpansion
if not defined DELF_POC (
  echo DelfUnits: DELF_POC is not set, so the committed .pas files are built
  exit /b 0
)
set "SRC=%~dp0"
set "SRC=%SRC:~0,-1%"
rem The project's unit search path (devcpp.dproj, DCC_UnitSearchPath) and unit scopes (DCC_Namespace)
set "U=%SRC%;%SRC%\VCL\ClassBrowsing;%SRC%\VCL\SVGIconImageList\Svg;%SRC%\VCL\SVGIconImageList\Source;%SRC%\VCL\devFileMonitor;%SRC%\VCL\devShortcuts;%SRC%\VCL\CompOptionsList;%SRC%\VCL\SynEdit\Source;%SRC%\VCL\vcl-styles-utils\Common;%SRC%\VCL\DDetours\Source"
set "NS=Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win"
set FAILED=0
pushd "%DELF_POC%"
for /r "%SRC%" %%F in (*.delf) do (
  python -m delfc "%%F" -U "%U%" --ns "%NS%" --check
  if errorlevel 1 set FAILED=1
)
popd
if !FAILED!==1 (
  echo DelfUnits: delfc reported errors
  exit /b 1
)
exit /b 0
