@echo off
title WinSetup
setlocal

:: WinSetup bootstrap — downloads WinSetup.ps1 from GitHub release and runs it.
:: Optional dev only: WinSetup.bat -local

if /I "%~1"=="-local" goto runlocal

set "SCRIPT_DIR=%TEMP%\WinSetup"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"

set "WS_URL=https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.ps1"
set "WS_BASE=https://github.com/Leviatan1121/WinSetup/releases/latest/download"
set "WS_DEST=%SCRIPT_DIR%\WinSetup.ps1"
set "DOWNLOADER=%SCRIPT_DIR%\WinSetup-BootstrapDownload.ps1"

if exist "%~dp0WinSetup-BootstrapDownload.ps1" (
  copy /Y "%~dp0WinSetup-BootstrapDownload.ps1" "%DOWNLOADER%" >nul
) else if exist "%DOWNLOADER%" (
  rem cached downloader
) else (
  curl.exe -fsSL -A WinSetup -o "%DOWNLOADER%" "%WS_BASE%/WinSetup-BootstrapDownload.ps1" 2>nul
)

if not exist "%DOWNLOADER%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%WS_BASE%/WinSetup-BootstrapDownload.ps1' -OutFile '%DOWNLOADER%' -UseBasicParsing -Headers @{UserAgent='WinSetup'}"
)

if not exist "%DOWNLOADER%" (
  echo [!] Could not download WinSetup-BootstrapDownload.ps1
  goto fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DOWNLOADER%" -Uri "%WS_URL%" -Dest "%WS_DEST%"
if errorlevel 1 goto fail

powershell -NoProfile -ExecutionPolicy Bypass -File "%WS_DEST%" -ScriptDir "%SCRIPT_DIR%"
goto end

:runlocal
set "SCRIPT_DIR=%TEMP%\WinSetup"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinSetup.ps1" -Local -ScriptDir "%SCRIPT_DIR%"
goto end

:end
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" goto fail
endlocal & exit /b 0

:fail
if not defined ERR set "ERR=%ERRORLEVEL%"
if "%ERR%"=="" set "ERR=1"
echo.
echo WinSetup failed ^(exit %ERR%^). See messages above.
pause
endlocal & exit /b %ERR%