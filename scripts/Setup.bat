@echo off

REM Check Internet conection
ping -n 1 8.8.8.8 > nul 2>&1
if errorlevel 1 (
    echo ERROR: No Internet connection.
    echo Check your network and try again.
    echo:
    pause
    exit /b
)

REM Download message
(echo|set /p="Downloading WinSetup") 
timeout /t 1 >nul
for /L %%i in (1,1,3) do (
    set /p="." <nul
    timeout /t 1 >nul
)
echo(
timeout /t 1 >nul

REM Create commands string
set str=timeout /t 3 & del /f /q "%~f0" & powershell -c "irm 'https://github.com/Leviatan1121/WinSetup/releases/download/latest/download.ps1' | iex"

REM Start new console and run commands
start cmd /c "%str%"
exit