@echo off
title WinSetup

:: WinSetup bootstrap — downloads WinSetup.ps1 from GitHub release and runs it.

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
