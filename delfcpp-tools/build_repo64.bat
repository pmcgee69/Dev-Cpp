@echo off
rem Win64 build of the Dev-C++ repo with MSBuild, outputs beside this script (devcpp-repo64).
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
set OUT=%~dp0devcpp-repo64
if not exist "%OUT%\units" mkdir "%OUT%\units"
cd /d C:\Users\User\Documents\GitHub2\Dev-Cpp-delf\Source
msbuild devcpp.dproj /nologo /v:minimal /t:Build /p:Config=Release /p:Platform=Win64 /p:DCC_MapFile=3 "/p:DCC_ExeOutput=%OUT%" "/p:DCC_DcuOutput=%OUT%\units"
echo EXIT %ERRORLEVEL%
