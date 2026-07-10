@echo off
title WinSetup

:: WinSetup bootstrap - downloads scripts from GitHub release and runs them in order.
:: UAC 1: Debloat + system Performance. UAC 2: Remove Windows AI. UAC 3 (last): Quick Assist + RDP.

:: Extract and run the embedded PowerShell block below.
powershell -NoProfile -Command "$f='%~f0'; $lines = Get-Content $f; $start = [array]::IndexOf($lines, '::POWERSHELL_START::') + 1; $end = [array]::IndexOf($lines, '::POWERSHELL_END::') - 1; $lines[$start..$end] | Out-String | Invoke-Expression"
pause
goto :eof
::POWERSHELL_START::

$ErrorActionPreference = 'Continue'

#region Workspace
$scriptDir = Join-Path $env:TEMP "WinSetup"
New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
#endregion

#region Windows Update Pauser
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Windows Update Pauser" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
$pauserUrl = "https://github.com/Leviatan1121/WindowsUpdatePauser/releases/latest/download/WindowsUpdatePauser.bat"
$pauserPath = Join-Path $scriptDir "WindowsUpdatePauser.bat"
Invoke-RestMethod -Uri $pauserUrl -OutFile $pauserPath
Start-Process -FilePath $pauserPath -Wait
#endregion

#region User PATH helpers
$BinDir = "$env:USERPROFILE\bin"
if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }

Set-Content -Path "$BinDir\AllowFile.bat" -Value @(
    '@echo off'
    'powershell -ExecutionPolicy Bypass -File "%~f1"'
)

$BatProcessContent = "@echo off`npowershell -NoExit -ExecutionPolicy Bypass"
Set-Content -Path "$BinDir\AllowProcess.bat" -Value $BatProcessContent

$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($UserPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$UserPath;$BinDir", "User")
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Environment configured." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
#endregion

#region Download release assets
$userScripts = "Configure.ps1", "Privacy.ps1", "Performance.ps1"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$baseUrl = "https://github.com/Leviatan1121/WinSetup/releases/latest/download"
$extraScripts = 'Install-MousePointerPrompt.ps1', 'Open-MousePointerSettings.ps1', 'Install-AppsPrompt.ps1', 'Open-InstallApps.ps1', 'InstallApps.ps1', 'Setup-Elevated.ps1', 'Debloat.ps1', 'RemoteSupport.ps1'
$downloads = @($userScripts) + $extraScripts
foreach ($File in $downloads) {
    Write-Host "[*] Downloading $File..." -ForegroundColor DarkGray
    Invoke-RestMethod -Uri "$baseUrl/$File" -OutFile (Join-Path $scriptDir $File)
}
#endregion

#region User pass (no admin)
foreach ($Script in $userScripts) {
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "[!] Running $Script" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    try {
        & (Join-Path $scriptDir $Script)
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Warning "$Script exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Warning "$Script failed: $($_.Exception.Message)"
    }
}
#endregion

#region Elevated pass (UAC 1 - Debloat + system Performance)
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Elevated pass - approve UAC (Debloat + Performance system)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

$elevatedPath = Join-Path $scriptDir 'Setup-Elevated.ps1'
if (Test-Path $elevatedPath) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $elevatedPath,
        '-ScriptDir', $scriptDir
    )
} else {
    Write-Warning 'Setup-Elevated.ps1 not found - skipping admin steps.'
}
#endregion

#region Remove Windows AI (elevated - before remote support)
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Remove Windows AI - approve UAC" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
try {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-Command', '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/zoicware/RemoveWindowsAI/main/RemoveWindowsAi.ps1")))'
    )
} catch {
    Write-Warning "RemoveWindowsAI failed: $($_.Exception.Message)"
}
#endregion

#region Remote support LAST (UAC 3 - Quick Assist, then RDP / restart prompt)
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Remote support tools (last step - RDP may ask to restart)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
$remoteSupportPath = Join-Path $scriptDir 'RemoteSupport.ps1'
if (Test-Path $remoteSupportPath) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $remoteSupportPath,
            '-WinSetupElevated'
        )
    } catch {
        Write-Warning "RemoteSupport.ps1 failed: $($_.Exception.Message)"
    }
} else {
    Write-Warning 'RemoteSupport.ps1 not found - skipping.'
}
#endregion

#region Mouse pointer settings after reboot (register last, before cleanup)
$promptInstaller = Join-Path $scriptDir 'Install-MousePointerPrompt.ps1'
if (Test-Path $promptInstaller) {
    try {
        . $promptInstaller
        Install-WinSetupMousePointerSettingsPrompt -SourceDir $scriptDir
        Write-Host '[*] Mouse pointer Settings will open after the next reboot.' -ForegroundColor DarkGray
    } catch {
        Write-Warning "Mouse settings prompt registration failed: $($_.Exception.Message)"
    }
}
#endregion

#region App installer after reboot (register last, before cleanup)
$appsPromptInstaller = Join-Path $scriptDir 'Install-AppsPrompt.ps1'
if (Test-Path $appsPromptInstaller) {
    try {
        . $appsPromptInstaller
        Install-WinSetupAppsPrompt -SourceDir $scriptDir
        Write-Host '[*] InstallApps will open after the next reboot.' -ForegroundColor DarkGray
    } catch {
        Write-Warning "App installer registration failed: $($_.Exception.Message)"
    }
}
#endregion

Write-Host "=========================================================" -ForegroundColor Yellow
Write-Host "[!] Baseline complete. Sign out and back in (or reboot)" -ForegroundColor Yellow
Write-Host "    so Performance preset shows correctly in sysdm.cpl." -ForegroundColor Yellow
Write-Host "    After reboot: Settings opens to Mouse pointer (pick your color)." -ForegroundColor Yellow
Write-Host "    After reboot: InstallApps opens to select software to install." -ForegroundColor Yellow
Write-Host "    If RDP uninstall prompted for restart, reboot when ready." -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor Yellow

#region Cleanup
Remove-Item $scriptDir -Recurse -Force -ErrorAction SilentlyContinue
#endregion
::POWERSHELL_END::
