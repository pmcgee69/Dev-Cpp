@echo off
rem Build Dev-C++ (Win32 Release) with Delphi 13 into folders beside this script, leaving the repo's own outputs alone.
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
set OUT=%~dp0devcpp-build
if not exist "%OUT%\units" mkdir "%OUT%\units"
cd /d C:\Users\User\Documents\GitHub2\Dev-Cpp\Source
msbuild devcpp.dproj /nologo /v:minimal /t:Build /p:Config=Release /p:Platform=Win32 /p:DCC_MapFile=3 "/p:DCC_ExeOutput=%OUT%" "/p:DCC_DcuOutput=%OUT%\units"
echo EXIT %ERRORLEVEL%
