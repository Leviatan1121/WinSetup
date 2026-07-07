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
}

Remove-BuiltInApps @(
    'Microsoft.WindowsFeedbackHub'           # Feedback Hub
    'Microsoft.BingWeather'                  # Weather
    'Microsoft.YourPhone'                    # Phone Link
    'MicrosoftCorporationII.MicrosoftFamily' # Family Safety
    'Microsoft.Getstarted'                   # Get Started (Introduccion)
    'Microsoft.StartExperiencesApp'          # Start Experiences (Get Started on newer builds)
    'Microsoft.MicrosoftJournal'             # Journal
    'Microsoft.MicrosoftOfficeHub'           # Microsoft 365 Copilot
    'Clipchamp.Clipchamp'                    # Clipchamp
    'MicrosoftTeams'                         # Teams (legacy package)
    'MSTeams'                                # Teams (current package)
    'Microsoft.Teams'                        # Teams (alternate package)
    'Microsoft.Todos'                        # To Do
    'Microsoft.Whiteboard'                   # Whiteboard
    'Microsoft.MicrosoftStickyNotes'       # Sticky Notes
    'Microsoft.BingNews'                     # News
    'Microsoft.OutlookForWindows'            # Outlook
    'Microsoft.OneConnect'                   # Mobile Plans
    'Microsoft.MicrosoftSolitaireCollection' # Solitaire Collection
  # 'Microsoft.GamingApp'                  # Casual Games (Xbox)
    '5319275A.WhatsAppDesktop'             # WhatsApp
)

winget uninstall --name "WhatsApp" --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall --id 5319275A.WhatsAppDesktop --silent --accept-source-agreements --disable-interactivity 2>$null
#endregion

#region Disable automatic installation of apps
# HKLM: "Turn off Microsoft consumer experiences" (blocks suggested apps system-wide)
$cloudContentPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
if (-not (Test-Path $cloudContentPolicy)) { New-Item -Path $cloudContentPolicy -Force | Out-Null }
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord

# HKCU: block silent/suggested app installs for the current user
$contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
Set-ItemProperty -Path $contentDelivery -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $contentDelivery -Name 'ContentDeliveryAllowed' -Value 0 -Type DWord
Set-ItemProperty -Path $contentDelivery -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $contentDelivery -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Debloat apps applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

#region Restart Explorer to apply changes
# Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
# Start-Process explorer.exe
#endregion