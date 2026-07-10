# WinSetup — register Open-InstallApps.ps1 for after next reboot (Run key + marker).
# Call once from WinSetup.ps1.

param(
    [switch]$Register,
    [string]$SourceDir = $PSScriptRoot
)

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

function Install-WinSetupAppsPrompt {
    param(
        [string]$SourceDir = $PSScriptRoot
    )

    Remove-WinSetupAppsLegacy

    $winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    if (-not (Test-Path $winSetupDir)) { New-Item -Path $winSetupDir -ItemType Directory -Force | Out-Null }

    $files = @(
        @{ Source = 'InstallApps.ps1'; Dest = 'InstallApps.ps1' }
        @{ Source = 'Open-InstallApps.ps1'; Dest = 'Open-InstallApps.ps1' }
    )

    foreach ($file in $files) {
        $source = Join-Path $SourceDir $file.Source
        $dest = Join-Path $winSetupDir $file.Dest
        if (-not (Test-Path $source)) {
            Write-Warning "$($file.Source) not found - skipping post-reboot app installer."
            return
        }
        Copy-Item -Path $source -Destination $dest -Force
    }

    $markerPath = Join-Path $winSetupDir '.open-install-apps-after-reboot'
    Set-Content -Path $markerPath -Value (Get-Date).ToUniversalTime().ToString('o') -Force

    $runner = Join-Path $winSetupDir 'Open-InstallApps.ps1'
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'WinSetup-InstallApps' -Value $cmd -Type String
}

if ($Register) {
    Install-WinSetupAppsPrompt -SourceDir $SourceDir
}
