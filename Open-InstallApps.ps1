# WinSetup — after reboot: launch InstallApps.ps1 once, then remove hook + payloads + self.
# InstallApps.ps1 does not self-delete; this runner cleans it up after it exits.
# Run key persists until LastBootUpTime is newer than the setup marker (real reboot).

$ErrorActionPreference = 'Continue'

$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$markerPath = Join-Path $winSetupDir '.open-install-apps-after-reboot'
$installScript = Join-Path $winSetupDir 'InstallApps.ps1'
$installCacheDir = Join-Path $env:TEMP 'WinSetup-Install'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'WinSetup-InstallApps'
$selfPath = $PSCommandPath

function Remove-WinSetupInstallAppsRunnerArtifacts {
    try {
        if (Test-Path -LiteralPath $installCacheDir) {
            Remove-Item -LiteralPath $installCacheDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    try {
        if (Test-Path -LiteralPath $markerPath) {
            Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    try {
        if (Test-Path -LiteralPath $installScript) {
            Remove-Item -LiteralPath $installScript -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    try {
        Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    } catch { }

    foreach ($task in @('WinSetup-InstallApps')) {
        try {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        } catch { }
        try {
            schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
        } catch { }
    }

    if ($selfPath -and (Test-Path -LiteralPath $selfPath)) {
        try {
            Start-Sleep -Milliseconds 500
            Remove-Item -LiteralPath $selfPath -Force -ErrorAction SilentlyContinue
        } catch { }
    }
}

if (-not (Test-Path -LiteralPath $markerPath)) {
    try {
        Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    } catch { }
    exit 0
}

try {
    $setupAt = (Get-Item -LiteralPath $markerPath).LastWriteTimeUtc
    $bootAt = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime()
} catch {
    Remove-WinSetupInstallAppsRunnerArtifacts
    exit 0
}

# Same boot session as setup (Explorer restart does not count) — wait for reboot.
if ($bootAt -le $setupAt) {
    exit 0
}

try {
    if (Test-Path -LiteralPath $installScript) {
        Start-Process -FilePath 'powershell.exe' -Wait -ArgumentList @(
            '-NoProfile'
            '-Sta'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            $installScript
        ) -ErrorAction Stop | Out-Null
    }
} catch { } finally {
    Remove-WinSetupInstallAppsRunnerArtifacts
}
