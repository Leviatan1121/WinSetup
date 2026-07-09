# WinSetup — one-shot at next logon: open Mouse pointer settings, then remove itself.
# Registered via RunOnce from Configure.ps1 / Setup.bat.

$runOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$runOnceName = 'WinSetup-MousePointerSettings'
$taskName = 'WinSetup-MousePointer'

Start-Process 'ms-settings:easeofaccess-mousepointer'

Remove-ItemProperty -Path $runOnceKey -Name $runOnceName -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'WinSetup-MousePointer' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null

if ($PSCommandPath) {
    Start-Sleep -Milliseconds 500
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
}
