# WinSetup — restore winget certificate pinning. Limited (non-elevated) only; called from WinSetup.ps1.

$ErrorActionPreference = 'Continue'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host '[*] winget not available — skipping certificate pinning restore.' -ForegroundColor DarkGray
    exit 0
}

Write-Host '[*] Restoring winget certificate pinning (non-elevated pass)...' -ForegroundColor DarkGray

& winget settings --disable BypassCertificatePinningForMicrosoftStore
if ($LASTEXITCODE -ne 0) {
    Write-Warning "winget settings --disable BypassCertificatePinningForMicrosoftStore failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host '[+] Certificate pinning restored.' -ForegroundColor Green
exit 0
