# WinSetup — after reboot: open Mouse pointer settings, remove hook + self, clean setup temp dir.
# Run key persists until LastBootUpTime is newer than the setup marker (real reboot).

$ErrorActionPreference = 'Continue'

$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$markerPath = Join-Path $winSetupDir '.open-mouse-after-reboot'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'WinSetup-MousePointerSettings'
$setupTempDir = Join-Path $env:TEMP 'WinSetup'
$selfPath = $PSCommandPath

function Remove-WinSetupMousePointerRunnerArtifacts {
    try {
        if (Test-Path -LiteralPath $setupTempDir) {
            Remove-Item -LiteralPath $setupTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    try {
        if (Test-Path -LiteralPath $markerPath) {
            Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    try {
        Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    } catch { }

    foreach ($task in @('WinSetup-MousePointer', 'WinSetup-MousePointerSettings')) {
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
    Remove-WinSetupMousePointerRunnerArtifacts
    exit 0
}

# Same boot session as setup (Explorer restart does not count) — wait for reboot.
if ($bootAt -le $setupAt) {
    exit 0
}

try {
    try {
        Start-Process 'ms-settings:easeofaccess-mousepointer' -ErrorAction Stop
    } catch { }
} finally {
    Remove-WinSetupMousePointerRunnerArtifacts
}
