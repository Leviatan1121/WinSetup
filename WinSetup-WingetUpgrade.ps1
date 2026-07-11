# WinSetup - upgrade App Installer (winget). Elevated only; called from WinSetup.ps1.

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'WinSetup-WingetHelpers.ps1')

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'winget is not available — skipping App Installer upgrade.'
    exit 0
}

Write-Host '[*] Updating App Installer (winget)...' -ForegroundColor Cyan

$versionBefore = Get-WinSetupAppInstallerVersion
if ($versionBefore) {
    Write-Host "[*] Installed version: $versionBefore" -ForegroundColor DarkGray
} else {
    Write-Host '[*] Installed version: (unknown)' -ForegroundColor DarkGray
}

Write-Host '[*] Enabling certificate pinning bypass for Microsoft Store...' -ForegroundColor DarkGray
$pinEnableExit = Invoke-WinSetupWingetCommand settings --enable BypassCertificatePinningForMicrosoftStore
if ($pinEnableExit -ne 0) {
    $pinEnable = Resolve-WinSetupWingetExitCode -ExitCode $pinEnableExit
    Write-Warning "winget settings --enable BypassCertificatePinningForMicrosoftStore failed ($($pinEnable.Name), exit $pinEnableExit)."
}

$upgradeExit = Invoke-WinSetupWingetCommand upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath"
Get-Command winget -ErrorAction SilentlyContinue | Out-Null

$versionAfter = Get-WinSetupAppInstallerVersion
if (-not $versionAfter) {
    $versionAfter = $versionBefore
}

$resolved = Resolve-WinSetupWingetExitCode -ExitCode $upgradeExit

if ($versionBefore -and $versionAfter -and $versionBefore -ne $versionAfter) {
    Write-Host "[+] App Installer upgraded ($versionBefore -> $versionAfter)." -ForegroundColor Green
} elseif ($resolved.IsBenign) {
    $displayVersion = if ($versionAfter) { $versionAfter } else { '(unknown)' }
    Write-Host "[+] App Installer already up to date (version $displayVersion)." -ForegroundColor Green
} else {
    Write-Warning "winget upgrade Microsoft.AppInstaller failed: $($resolved.Name) (exit $($resolved.ExitCode)). Try running with --verbose-logs."
}

Write-Host '[*] Restoring winget certificate pinning...' -ForegroundColor DarkGray
$pinDisableExit = Invoke-WinSetupWingetCommand settings --disable BypassCertificatePinningForMicrosoftStore
if ($pinDisableExit -ne 0) {
    $pinDisable = Resolve-WinSetupWingetExitCode -ExitCode $pinDisableExit
    Write-Warning "winget settings --disable BypassCertificatePinningForMicrosoftStore failed ($($pinDisable.Name), exit $pinDisableExit)."
} else {
    Write-Host '[+] Certificate pinning restored.' -ForegroundColor Green
}

exit 0
