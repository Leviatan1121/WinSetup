$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if (-not $PSCommandPath) {
        Write-Error "Debloat.ps1 must be run from a file (e.g. Setup.bat or AllowFile.bat)."
        exit 1
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit $LASTEXITCODE
}

#region Widgets
# Disable system-wide and uninstall the Web Experience Pack
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction SilentlyContinue

$DshPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (-not (Test-Path $DshPath)) { New-Item -Path $DshPath -Force | Out-Null }
Set-ItemProperty -Path $DshPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord

Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -ErrorAction SilentlyContinue |
    Remove-AppxPackage -ErrorAction SilentlyContinue

Get-AppxPackage -AllUsers -Name "MicrosoftWindows.Client.WebExperience" -ErrorAction SilentlyContinue |
    Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object DisplayName -Like '*WebExperience*' |
    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }

winget uninstall --id 9MSSGKG348SP --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall "Windows Web Experience Pack" --silent --accept-source-agreements --disable-interactivity 2>$null
#endregion

#region Copilot
# Hide from taskbar, disable via policy, and uninstall the app
Set-ItemProperty -Path $ExplorerPath -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue

foreach ($hive in @('HKLM:\SOFTWARE\Policies', 'HKCU:\Software\Policies')) {
    $copilotPath = "$hive\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $copilotPath)) { New-Item -Path $copilotPath -Force | Out-Null }
    Set-ItemProperty -Path $copilotPath -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord

    $aiPath = "$hive\Microsoft\Windows\WindowsAI"
    if (-not (Test-Path $aiPath)) { New-Item -Path $aiPath -Force | Out-Null }
    Set-ItemProperty -Path $aiPath -Name "RemoveMicrosoftCopilotApp" -Value 1 -Type DWord
}

foreach ($package in @('Microsoft.Copilot', 'Microsoft.Windows.Copilot')) {
    Get-AppxPackage -Name $package -ErrorAction SilentlyContinue |
        Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxPackage -AllUsers -Name $package -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}

Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object DisplayName -Like '*Copilot*' |
    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }

winget uninstall --id Microsoft.Copilot_8wekyb3d8bbwe --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall --name "Microsoft Copilot" --silent --accept-source-agreements --disable-interactivity 2>$null
#endregion

#region OneDrive
# Stop, uninstall, and block reinstall
Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

winget uninstall --name "Microsoft OneDrive" --silent --accept-source-agreements --disable-interactivity 2>$null

foreach ($setupPath in @(
    "$env:SystemRoot\System32\OneDriveSetup.exe",
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
)) {
    if (Test-Path $setupPath) {
        Start-Process -FilePath $setupPath -ArgumentList '/uninstall', '/allusers' -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
}

$uninstallKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
)
foreach ($key in $uninstallKeys) {
    $uninstallString = (Get-ItemProperty -Path $key -Name UninstallString -ErrorAction SilentlyContinue).UninstallString
    if ($uninstallString) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $uninstallString -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
}

$oneDrivePolicyPath = 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive'
if (-not (Test-Path $oneDrivePolicyPath)) { New-Item -Path $oneDrivePolicyPath -Force | Out-Null }
Set-ItemProperty -Path $oneDrivePolicyPath -Name 'DisableFileSyncNGSC' -Value 1 -Type DWord
Set-ItemProperty -Path $oneDrivePolicyPath -Name 'DisableFileSync' -Value 1 -Type DWord
#endregion

#region Built-in apps
function Remove-BuiltInApps {
    param([string[]]$PackageNames)

    foreach ($name in $PackageNames) {
        Get-AppxPackage -Name $name -ErrorAction SilentlyContinue |
            Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxPackage -AllUsers -Name $name -ErrorAction SilentlyContinue |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object PackageName -Like "$name*" |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
    }
}

Remove-BuiltInApps @(
    'Microsoft.WindowsFeedbackHub'          # Feedback Hub (Opinion Center)
    'Microsoft.BingWeather'               # Weather
    'Microsoft.YourPhone'                   # Phone Link
    'MicrosoftCorporationII.MicrosoftFamily' # Family Safety
    'Microsoft.Getstarted'                  # Get Started
    'Microsoft.MicrosoftJournal'            # Journal
    'Microsoft.MicrosoftOfficeHub'          # Microsoft 365 Copilot
    'Clipchamp.Clipchamp'                   # Clipchamp
    'MicrosoftTeams'                        # Teams (legacy package)
    'MSTeams'                               # Teams (current package)
    'Microsoft.Teams'                     # Teams (alternate package)
    'Microsoft.Todos'                     # To Do
    'Microsoft.Whiteboard'                # Whiteboard
    'Microsoft.MicrosoftStickyNotes'      # Sticky Notes
    'Microsoft.BingNews'                  # News
    'Microsoft.OutlookForWindows'         # Outlook
    'Microsoft.OneConnect'                # Mobile Plans
    'Microsoft.MicrosoftSolitaireCollection' # Solitaire Collection
    # 'Microsoft.GamingApp'                 # Casual Games (Xbox)
)
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Debloat apps applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

#region Restart Explorer to apply changes
# Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
# Start-Process explorer.exe
#endregion