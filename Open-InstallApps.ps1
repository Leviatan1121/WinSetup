# WinSetup — after reboot: launch InstallApps.ps1 once, then remove hook + payloads + self.
# Run key persists until LastBootUpTime is newer than the setup marker (real reboot).

$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$markerPath = Join-Path $winSetupDir '.open-install-apps-after-reboot'
$installScript = Join-Path $winSetupDir 'InstallApps.ps1'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'WinSetup-InstallApps'

if (-not (Test-Path $markerPath)) {
    Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    exit 0
}

$setupAt = (Get-Item -LiteralPath $markerPath).LastWriteTimeUtc
$bootAt = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()

# Same boot session as setup (Explorer restart does not count) — wait for reboot.
if ($bootAt -le $setupAt) {
    exit 0
}

if (Test-Path -LiteralPath $installScript) {
    Start-Process -FilePath 'powershell.exe' -Wait -ArgumentList @(
        '-NoProfile'
        '-Sta'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $installScript
    ) | Out-Null
}

Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $installScript -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue

foreach ($task in @('WinSetup-InstallApps')) {
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
    schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
}

if ($PSCommandPath) {
    Start-Sleep -Milliseconds 500
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
}
