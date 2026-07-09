# WinSetup — single elevated pass (one UAC). Called from Setup.bat only.
# Order: Debloat → Performance (HKLM) → pointer refresh → RemoteSupport (Quick Assist, then RDP).

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptDir
)

#region Elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error 'Setup-Elevated.ps1 must run with administrator privileges.'
    exit 1
}
#endregion

$ErrorActionPreference = 'Continue'

Write-Host '=========================================================' -ForegroundColor Cyan
Write-Host '[!] WinSetup elevated pass (admin)' -ForegroundColor Cyan
Write-Host '=========================================================' -ForegroundColor Cyan

#region Debloat
$debloatPath = Join-Path $ScriptDir 'Debloat.ps1'
if (Test-Path $debloatPath) {
    Write-Host '[*] Running Debloat.ps1...' -ForegroundColor DarkGray
    & $debloatPath -WinSetupElevated
}
#endregion

#region Performance (HKLM only)
$performancePath = Join-Path $ScriptDir 'Performance.ps1'
if (Test-Path $performancePath) {
    Write-Host '[*] Running Performance.ps1 (system)...' -ForegroundColor DarkGray
    & $performancePath -SystemOnly
}
#endregion

#region Pointer refresh after Explorer restart in Debloat
$setPointerPath = Join-Path $ScriptDir 'Set-MousePointer.ps1'
$cursorZip = Join-Path $ScriptDir 'Cursors.zip'
if (Test-Path $setPointerPath) {
    Write-Host '[*] Refreshing mouse pointer...' -ForegroundColor DarkGray
    . $setPointerPath
    Set-WinSetupMousePointer -CursorsZip $cursorZip
}
#endregion

#region Remote support (last — RDP may prompt for restart)
$remoteSupportPath = Join-Path $ScriptDir 'RemoteSupport.ps1'
if (Test-Path $remoteSupportPath) {
    Write-Host '[*] Running RemoteSupport.ps1...' -ForegroundColor DarkGray
    & $remoteSupportPath -WinSetupElevated
}
#endregion

Write-Host '=========================================================' -ForegroundColor Cyan
Write-Host '[!] Elevated pass finished.' -ForegroundColor Cyan
Write-Host '=========================================================' -ForegroundColor Cyan
