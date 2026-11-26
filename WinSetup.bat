@echo off
title WinSetup

:: WinSetup bootstrap — downloads WinSetup.ps1 from GitHub release and runs it.
:: Optional dev only: WinSetup.bat -local

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

set "WS_URL=https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.ps1"
set "WS_DEST=%SCRIPT_DIR%\WinSetup.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$ProgressPreference='SilentlyContinue';" ^
  "Write-Host '[*] Downloading WinSetup.ps1...' -ForegroundColor DarkGray;" ^
  "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }" ^
  "$url='%WS_URL%';" ^
  "$dest='%WS_DEST%';" ^
  "$headers=@{ 'User-Agent'='WinSetup' };" ^
  "$ok=$false;" ^
  "if (Get-Command curl.exe -ErrorAction SilentlyContinue) {" ^
  "  try { & curl.exe -fsSL -A WinSetup -o $dest $url; if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 0) { $ok=$true } } catch { }" ^
  "}" ^
  "if (-not $ok) {" ^
  "  for ($a=1; $a -le 3; $a++) { if ($ok) { break }; try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers $headers; if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 0) { $ok=$true } } catch { if ($a -lt 3) { Start-Sleep -Seconds (2*$a) } } };" ^
  "}" ^
  "if (-not $ok) {" ^
  "  try { $wc=New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent','WinSetup'); $wc.DownloadFile($url,$dest); $ok=(Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 0 } catch { }" ^
  "}" ^
  "if (-not $ok) { Write-Host '[!] Could not download WinSetup.ps1. Check network, proxy, or try again later.' -ForegroundColor Red; exit 1 }" ^
  "& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dest -ScriptDir '%SCRIPT_DIR%'"

exit /b %ERRORLEVEL%