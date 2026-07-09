# WinSetup — optional removal of Quick Assist and Remote Desktop Connection.
# Self-elevates when run alone; Setup.bat uses Setup-Elevated.ps1 with -WinSetupElevated.
# Order: Quick Assist first, then Remote Desktop Connection (last — may prompt restart).

param([switch]$WinSetupElevated)

#region Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($WinSetupElevated) {
    if (-not $isAdmin) {
        Write-Error 'RemoteSupport.ps1 -WinSetupElevated requires an administrator session.'
        exit 1
    }
} elseif (-not $isAdmin) {
    if (-not $PSCommandPath) {
        Write-Error 'RemoteSupport.ps1 must be run from a file (e.g. Setup.bat or AllowFile.bat).'
        exit 1
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit $LASTEXITCODE
}
#endregion

function Confirm-OptionalUninstall {
    param(
        [string]$AppName,
        [string]$Note
    )

    Write-Host ""
    Write-Host "Uninstall '$AppName'? [Enter = Yes, any key = No]" -ForegroundColor Yellow
    if ($Note) { Write-Host $Note -ForegroundColor DarkGray }
    $response = Read-Host
    return [string]::IsNullOrWhiteSpace($response)
}

#region Quick Assist
$quickAssistInstalled = @(
    Get-AppxPackage -Name 'MicrosoftCorporationII.QuickAssist' -ErrorAction SilentlyContinue
    Get-AppxPackage -AllUsers -Name 'MicrosoftCorporationII.QuickAssist' -ErrorAction SilentlyContinue
) | Where-Object { $_ } | Select-Object -First 1

if (-not $quickAssistInstalled) {
    $quickAssistInstalled = Get-WindowsCapability -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'App.Support.QuickAssist*' -and $_.State -eq 'Installed' } |
        Select-Object -First 1
}

if ($quickAssistInstalled -and (Confirm-OptionalUninstall -AppName 'Quick Assist')) {
    foreach ($name in @('MicrosoftCorporationII.QuickAssist')) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name -or $_.Name -like "$name*" } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
        Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name -or $_.Name -like "$name*" } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $name -or $_.PackageName -like "$name*" } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
    }

    Get-WindowsCapability -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'App.Support.QuickAssist*' -and $_.State -eq 'Installed' } |
        ForEach-Object { Remove-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null }
}
#endregion

#region Remote Desktop Connection
$mstsc = Join-Path $env:SystemRoot 'System32\mstsc.exe'
if ((Test-Path $mstsc) -and (Confirm-OptionalUninstall -AppName 'Remote Desktop Connection' -Note 'Restart is required to finish removal — choose Restart later to stay in this session.')) {
    Start-Process -FilePath $mstsc -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
}
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Remote support tools step finished." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
