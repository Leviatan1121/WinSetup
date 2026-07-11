@echo off
title WinSetup

:: WinSetup bootstrap — downloads WinSetup.ps1 from GitHub release and runs it.
:: Pass -local to run scripts from this folder (no download).

set "LOCAL_ARG="
if /I "%~1"=="-local" set "LOCAL_ARG=1"

if defined LOCAL_ARG (
  set "SCRIPT_DIR=%~dp0"
  if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\WinSetup.ps1" -Local -ScriptDir "%SCRIPT_DIR%"
  exit /b %ERRORLEVEL%
)

set "SCRIPT_DIR=%TEMP%\WinSetup"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$dir='%SCRIPT_DIR%';" ^
  "$url='https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.ps1';" ^
  "$dest=Join-Path $dir 'WinSetup.ps1';" ^
  "Write-Host '[*] Downloading WinSetup.ps1...' -ForegroundColor DarkGray;" ^
  "Invoke-RestMethod -Uri $url -OutFile $dest;" ^
  "& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dest -ScriptDir $dir"

exit /b %ERRORLEVEL%
