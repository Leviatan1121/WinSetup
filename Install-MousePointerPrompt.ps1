# Post-reboot hook: copies Open-MousePointerSettings.ps1 to %LOCALAPPDATA%\WinSetup
# and registers it in HKCU\...\Run. Runs once silently from WinSetup.ps1 (-Register).

param(
    [switch]$Register,
    [string]$SourceDir = $PSScriptRoot
)

#region Legacy cleanup
function Remove-WinSetupCursorLegacy {
    $startupPath = [Environment]::GetFolderPath('Startup')
    $winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    $userCursors = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'

    foreach ($name in @('WinSetup-ApplyCursor.bat', 'WinSetup-ApplyCursor.vbs')) {
        Remove-Item (Join-Path $startupPath $name) -Force -ErrorAction SilentlyContinue
    }

    foreach ($task in @('WinSetup-ApplyCursor', 'WinSetup-MousePointer', 'WinSetup-MousePointerSettings')) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
    }

    foreach ($runKey in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    )) {
        foreach ($prop in @('WinSetup-ApplyCursor', 'WinSetup-MousePointer', 'WinSetup-MousePointerSettings')) {
            Remove-ItemProperty -Path $runKey -Name $prop -ErrorAction SilentlyContinue
        }
    }

    foreach ($legacyScript in @(
        'Set-MousePointer.ps1',
        'Apply-MousePointer.ps1',
        'Apply-MousePointerAtLogon.ps1',
        'Apply-Cursor.ps1'
    )) {
        Remove-Item (Join-Path $winSetupDir $legacyScript) -Force -ErrorAction SilentlyContinue
    }

    Remove-Item (Join-Path $winSetupDir 'Cursors') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $winSetupDir 'Cursors.zip') -Force -ErrorAction SilentlyContinue

    Get-ChildItem -Path $userCursors -Filter '*_eoa.cur' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
#endregion

#region Post-reboot registration
function Install-WinSetupMousePointerSettingsPrompt {
    param([string]$SourceDir = $PSScriptRoot)

    Remove-WinSetupCursorLegacy

    $winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    if (-not (Test-Path $winSetupDir)) { New-Item -Path $winSetupDir -ItemType Directory -Force | Out-Null }

    $source = Join-Path $SourceDir 'Open-MousePointerSettings.ps1'
    if (-not (Test-Path $source)) { return }

    $dest = Join-Path $winSetupDir 'Open-MousePointerSettings.ps1'
    Copy-Item -Path $source -Destination $dest -Force

    $markerPath = Join-Path $winSetupDir '.open-mouse-after-reboot'
    Set-Content -Path $markerPath -Value (Get-Date).ToUniversalTime().ToString('o') -Force

    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'WinSetup-MousePointerSettings' -Value $cmd -Type String
}
#endregion

if ($Register) {
    Install-WinSetupMousePointerSettingsPrompt -SourceDir $SourceDir
}
