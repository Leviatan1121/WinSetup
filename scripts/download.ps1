rm "$env:TEMP\WinSetup.exe" -ErrorAction SilentlyContinue
rm "$env:USERPROFILE\Desktop\WinSetup.exe" -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri "https://github.com/Leviatan1121/WinSetup/releases/download/latest/WinSetup.exe" -OutFile "$env:USERPROFILE\Desktop\WinSetup.exe"