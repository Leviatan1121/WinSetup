# WinSetup - upgrade App Installer (winget). Elevated only; called from WinSetup.ps1.

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'WinSetup-WingetHelpers.ps1')

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'winget is not available — skipping App Installer upgrade.'
    exit 0
}

Write-Host '[*] Updating App Installer (winget)...' -ForegroundColor DarkGray

$versionBefore = Get-WinSetupAppInstallerVersion
$resolved = Invoke-WinSetupAppInstallerUpgradeWithPinBypass
$versionAfter = Get-WinSetupAppInstallerVersion
if (-not $versionAfter) {
    $versionAfter = $versionBefore
}

if ($versionBefore -and $versionAfter -and $versionBefore -ne $versionAfter) {
    Write-Host "[+] App Installer upgraded ($versionBefore -> $versionAfter)." -ForegroundColor Green
} elseif ($resolved.IsBenign -or $resolved.IsSuccess) {
    Write-Host '[+] App Installer already up to date.' -ForegroundColor Green
} else {
    Write-Warning "winget upgrade Microsoft.AppInstaller failed: $($resolved.Name) (exit $($resolved.ExitCode)). Try running with --verbose-logs."
}

exit 0
