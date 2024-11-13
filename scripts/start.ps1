rm "$env:TEMP\WinSetup.exe" -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri "https://github.com/Leviatan1121/WinSetup/releases/download/latest/WinSetup.exe" -OutFile "$env:TEMP\WinSetup.exe"
start "$env:TEMP\WinSetup.exe"