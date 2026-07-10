# WinSetup — after reboot: open Mouse pointer settings, remove hook + self, clean setup temp dir.
# Run key persists until LastBootUpTime is newer than the setup marker (real reboot).

$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$markerPath = Join-Path $winSetupDir '.open-mouse-after-reboot'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'WinSetup-MousePointerSettings'

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

$setupTempDir = Join-Path $env:TEMP 'WinSetup'
if (Test-Path -LiteralPath $setupTempDir) {
    Remove-Item -LiteralPath $setupTempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Start-Process 'ms-settings:easeofaccess-mousepointer'

Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue

foreach ($task in @('WinSetup-MousePointer', 'WinSetup-MousePointerSettings')) {
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
    schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
}

if ($PSCommandPath) {
    Start-Sleep -Milliseconds 500
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
}
