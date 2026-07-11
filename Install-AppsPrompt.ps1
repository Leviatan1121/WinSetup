# Post-reboot hook: copies InstallApps.ps1 + Open-InstallApps.ps1 to %LOCALAPPDATA%\WinSetup
# and registers the runner in HKCU\...\Run. Runs once silently from WinSetup.ps1 (-Register).

param(
    [switch]$Register,
    [string]$SourceDir = $PSScriptRoot
)

#region Legacy cleanup
function Remove-WinSetupAppsLegacy {
    $winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'

    foreach ($task in @('WinSetup-InstallApps')) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
    }

    foreach ($runKey in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    )) {
        Remove-ItemProperty -Path $runKey -Name 'WinSetup-InstallApps' -ErrorAction SilentlyContinue
    }

    foreach ($legacyScript in @('Install.ps1', 'Open-InstallApps.ps1')) {
        Remove-Item (Join-Path $winSetupDir $legacyScript) -Force -ErrorAction SilentlyContinue
    }

    Remove-Item (Join-Path $winSetupDir '.open-install-apps-after-reboot') -Force -ErrorAction SilentlyContinue
}
#endregion

#region Post-reboot registration
function Install-WinSetupAppsPrompt {
    param([string]$SourceDir = $PSScriptRoot)

    Remove-WinSetupAppsLegacy

    $winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    if (-not (Test-Path $winSetupDir)) { New-Item -Path $winSetupDir -ItemType Directory -Force | Out-Null }

    foreach ($file in @('InstallApps.ps1', 'Open-InstallApps.ps1')) {
        $source = Join-Path $SourceDir $file
        if (-not (Test-Path $source)) { return }
        Copy-Item -Path $source -Destination (Join-Path $winSetupDir $file) -Force
    }

    $markerPath = Join-Path $winSetupDir '.open-install-apps-after-reboot'
    Set-Content -Path $markerPath -Value (Get-Date).ToUniversalTime().ToString('o') -Force

    $runner = Join-Path $winSetupDir 'Open-InstallApps.ps1'
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'WinSetup-InstallApps' -Value $cmd -Type String
}
#endregion

if ($Register) {
    Install-WinSetupAppsPrompt -SourceDir $SourceDir
}
