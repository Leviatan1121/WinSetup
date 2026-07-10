$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if (-not $PSCommandPath) {
        Write-Error "Sandbox.ps1 must be run from a file (e.g. AllowFile.bat)."
        exit 1
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit $LASTEXITCODE
}

function Confirm-Continue {
    param([string]$Prompt)

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Yellow
    $response = Read-Host
    return [string]::IsNullOrWhiteSpace($response)
}

function Test-SandboxEditionSupported {
    param([string]$EditionId)

    $EditionId -in @(
        'Professional'
        'ProfessionalEducation'
        'ProfessionalWorkstation'
        'Enterprise'
        'EnterpriseN'
        'Education'
        'ServerStandard'
        'ServerDatacenter'
    )
}

$editionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID).EditionID
Write-Host "Current edition: $editionId" -ForegroundColor Cyan

if (-not (Test-SandboxEditionSupported -EditionId $editionId)) {
    Write-Host "Windows Sandbox is not supported on this edition (Pro, Enterprise, or Education required)." -ForegroundColor DarkYellow
    exit 0
}

$virtEnabled = (Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue).VirtualizationFirmwareEnabled
if ($virtEnabled -eq $false) {
    Write-Error "Hardware virtualization is disabled in BIOS/UEFI. Enable Intel VT-x or AMD-V, then run this script again."
    exit 1
}
if ($null -eq $virtEnabled) {
    Write-Host "Could not verify BIOS virtualization. Continuing anyway..." -ForegroundColor DarkYellow
}

$sandboxFeature = 'Containers-DisposableClientVM'
$state = (Get-WindowsOptionalFeature -Online -FeatureName $sandboxFeature -ErrorAction SilentlyContinue).State

if ($state -eq 'Enabled') {
    Write-Host "Windows Sandbox is already enabled." -ForegroundColor Green
} else {
    Write-Host "Enabling Windows Sandbox..." -ForegroundColor Cyan
    $result = Enable-WindowsOptionalFeature -Online -FeatureName $sandboxFeature -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) {
        Write-Host "Restart required to finish installing Windows Sandbox." -ForegroundColor Yellow
        if (Confirm-Continue -Prompt "Restart now? [Enter = Yes, any key = No]") {
            Restart-Computer -Force
        }
    } else {
        Write-Host "Windows Sandbox enabled." -ForegroundColor Green
    }
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Done. Launch from Start > Windows Sandbox." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
