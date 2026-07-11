# WinSetup — upgrade App Installer (winget). Elevated only; called from WinSetup.ps1.

$ErrorActionPreference = 'Continue'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'winget is not available — skipping App Installer upgrade.'
    Read-Host 'Presione Enter para continuar'
    exit 0
}

Write-Host '[*] Updating App Installer (winget)...' -ForegroundColor Cyan

& winget settings --enable BypassCertificatePinningForMicrosoftStore
if ($LASTEXITCODE -ne 0) {
    Write-Warning "winget settings --enable BypassCertificatePinningForMicrosoftStore failed (exit $LASTEXITCODE)."
}

& winget upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    Write-Warning "winget upgrade Microsoft.AppInstaller failed or no update available (exit $LASTEXITCODE)."
} else {
    Write-Host '[+] App Installer upgraded.' -ForegroundColor Green
}

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath"
Get-Command winget -ErrorAction SilentlyContinue | Out-Null

Write-Host '[*] Restoring winget certificate pinning...' -ForegroundColor DarkGray
& winget settings --disable BypassCertificatePinningForMicrosoftStore
if ($LASTEXITCODE -ne 0) {
    Write-Warning "winget settings --disable BypassCertificatePinningForMicrosoftStore failed (exit $LASTEXITCODE)."
} else {
    Write-Host '[+] Certificate pinning restored.' -ForegroundColor Green
}

Read-Host 'Presione Enter para continuar'
exit 0
