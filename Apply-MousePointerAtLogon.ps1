# WinSetup — logon helper: wait for Explorer, then re-apply custom pointer.
# Scheduled task runs ~15s after logon; removes itself after 3 successful applies.

$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$setPointerPath = Join-Path $winSetupDir 'Set-MousePointer.ps1'
$cursorZip = Join-Path $winSetupDir 'Cursors.zip'
$taskName = 'WinSetup-MousePointer'
$statePath = 'HKCU:\Software\WinSetup'

if (-not (Test-Path $setPointerPath)) { exit 0 }

for ($i = 0; $i -lt 120; $i++) {
    if (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue) { break }
    Start-Sleep -Seconds 1
}

Start-Sleep -Seconds 15

. $setPointerPath
Set-WinSetupMousePointer -CursorsZip $cursorZip

Start-Sleep -Seconds 5
Set-WinSetupMousePointer -CursorsZip $cursorZip

$accessibilityPath = 'HKCU:\Software\Microsoft\Accessibility'
$cursorType = (Get-ItemProperty -Path $accessibilityPath -Name 'CursorType' -ErrorAction SilentlyContinue).CursorType

if ($cursorType -eq 6) {
    if (-not (Test-Path $statePath)) { New-Item -Path $statePath -Force | Out-Null }
    $count = (Get-ItemProperty -Path $statePath -Name 'MousePointerLogonCount' -ErrorAction SilentlyContinue).MousePointerLogonCount
    if ($null -eq $count) { $count = 0 }
    $count++
    Set-ItemProperty -Path $statePath -Name 'MousePointerLogonCount' -Value $count -Type DWord

    if ($count -ge 3) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}
