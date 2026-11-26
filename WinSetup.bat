@echo off
title WinSetup

:: WinSetup bootstrap — downloads WinSetup.ps1 from GitHub release and runs it.
:: Pass -local to run scripts from this folder (no download).
:: If WinSetup.ps1 sits next to this .bat, it is used instead of the release copy.

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

if exist "%~dp0WinSetup.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinSetup.ps1" -Local -ScriptDir "%SCRIPT_DIR%"
  exit /b %ERRORLEVEL%
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$ProgressPreference='SilentlyContinue';" ^
  "Write-Host '[*] Downloading WinSetup.ps1...' -ForegroundColor DarkGray;" ^
  "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }" ^
  "$dir='%SCRIPT_DIR%';" ^
  "$url='https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.ps1';" ^
  "$dest=Join-Path $dir 'WinSetup.ps1';" ^
  "$headers=@{ 'User-Agent'='WinSetup' };" ^
  "$ok=$false;" ^
  "1..3 | ForEach-Object { if ($ok) { return }; try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers $headers; if ((Test-Path $dest) -and (Get-Item $dest).Length -gt 0) { $ok=$true } } catch { Start-Sleep -Seconds (2 * $_) } };" ^
  "if (-not $ok) { $wc=New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent','WinSetup'); $wc.DownloadFile($url,$dest); $ok=$true };" ^
  "& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dest -ScriptDir $dir"

exit /b %ERRORLEVEL%