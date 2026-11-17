@echo off
rem Build the dev64 worktree (plain Delphi, Delf-inspired fixes) for Win32 and Win64 into folders beside this script.
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
cd /d C:\Users\User\Documents\GitHub2\Dev-Cpp-dev64\Source
for %%P in (Win32 Win64) do (
  if not exist "%~dp0dev64-%%P\units" mkdir "%~dp0dev64-%%P\units"
  msbuild devcpp.dproj /nologo /v:minimal /t:Build /p:Config=Release /p:Platform=%%P "/p:DCC_ExeOutput=%~dp0dev64-%%P" "/p:DCC_DcuOutput=%~dp0dev64-%%P\units"
  echo %%P EXIT !ERRORLEVEL! %ERRORLEVEL%
)
