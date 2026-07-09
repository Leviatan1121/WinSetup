# WinSetup — system-wide removals, policies, and elevated privacy (HKLM + all users).
# Self-elevates via UAC when not admin. Run last in Setup.bat.
# Run order: Setup.bat → Configure.ps1 → Privacy.ps1 → Debloat.ps1 → Performance.ps1

#region Elevation
# Re-launch this script elevated; required for HKLM, services, and all-user Appx removal.
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
#endregion

#region System > Power > Fast startup
# Disable hiberboot (fast startup) — avoids stale driver/state issues on some hardware.
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord
#endregion

#region Privacy > Location (elevated)
# Turns OFF device location services and suppresses location prompts system-wide.
# Privacy.ps1 handles per-user HKCU consent; this section handles HKLM + CAM cache.
$adminFlows = Join-Path $env:WINDIR 'System32\SystemSettingsAdminFlows.exe'
if (Test-Path $adminFlows) {
    # Toggle 1→0 forces CAM to register the global OFF state (visible in Procmon on 24H2+).
    & $adminFlows SetCamSystemGlobal location 1 | Out-Null
    Start-Sleep -Milliseconds 400
    & $adminFlows SetCamSystemGlobal location 0 | Out-Null
    & $adminFlows SetGeolocationMaster 1 | Out-Null
    Start-Sleep -Milliseconds 400
    & $adminFlows SetGeolocationMaster 0 | Out-Null
}

# Group Policy: Turn off location scripting / sensors.
$locationPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
if (-not (Test-Path $locationPolicy)) { New-Item -Path $locationPolicy -Force | Out-Null }
Set-ItemProperty -Path $locationPolicy -Name 'DisableLocation' -Value 1 -Type DWord

# Machine-wide consent store (Settings reads HKLM on elevated toggles).
$locationHklm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
if (-not (Test-Path $locationHklm)) { New-Item -Path $locationHklm -Force | Out-Null }
Set-ItemProperty -Path $locationHklm -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationHklm -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

$locationNonPackagedHklm = Join-Path $locationHklm 'NonPackaged'
if (-not (Test-Path $locationNonPackagedHklm)) { New-Item -Path $locationNonPackagedHklm -Force | Out-Null }
Set-ItemProperty -Path $locationNonPackagedHklm -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationNonPackagedHklm -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

# Pulse ShowGlobalPrompts 1→0 so CapabilityConsentStorage.db rebuilds with notify=OFF on 26200+.
# HKCU consent values are set in Privacy.ps1; this section only refreshes the CAM cache.
$locationConsentParentHkcu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
$locationHkcu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
$locationNonPackagedHkcu = Join-Path $locationHkcu 'NonPackaged'
foreach ($promptPath in @($locationConsentParentHkcu, $locationHkcu, $locationNonPackagedHkcu)) {
    Set-ItemProperty -Path $promptPath -Name 'ShowGlobalPrompts' -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 300
foreach ($promptPath in @($locationConsentParentHkcu, $locationHkcu, $locationNonPackagedHkcu)) {
    Set-ItemProperty -Path $promptPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

# Delete CAM SQLite caches; camsvc/lfsvc recreate them from registry on next start.
$camDbDir = Join-Path $env:ProgramData 'Microsoft\Windows\CapabilityAccessManager'
foreach ($svc in @('lfsvc', 'camsvc')) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
}
foreach ($dbBase in @('CapabilityAccessManager', 'CapabilityConsentStorage')) {
    foreach ($suffix in @('.db', '.db-wal', '.db-shm')) {
        Remove-Item (Join-Path $camDbDir ($dbBase + $suffix)) -Force -ErrorAction SilentlyContinue
    }
}
foreach ($svc in @('camsvc', 'lfsvc')) {
    Start-Service -Name $svc -ErrorAction SilentlyContinue
}

Get-Process -Name 'SystemSettings' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#endregion

#region Personalization > Taskbar > Widgets
# Hide widgets on the taskbar and remove the Web Experience Pack (News and interests).
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

#region Copilot and Recall
# Taskbar button, Copilot Appx, Windows AI policies (Recall snapshots off).
Set-ItemProperty -Path $ExplorerPath -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue

foreach ($hive in @('HKLM:\SOFTWARE\Policies', 'HKCU:\Software\Policies')) {
    $copilotPath = "$hive\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $copilotPath)) { New-Item -Path $copilotPath -Force | Out-Null }
    Set-ItemProperty -Path $copilotPath -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord

    $aiPath = "$hive\Microsoft\Windows\WindowsAI"
    if (-not (Test-Path $aiPath)) { New-Item -Path $aiPath -Force | Out-Null }
    Set-ItemProperty -Path $aiPath -Name "RemoveMicrosoftCopilotApp" -Value 1 -Type DWord
    Set-ItemProperty -Path $aiPath -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord
}

$windowsAiPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
if (-not (Test-Path $windowsAiPolicy)) { New-Item -Path $windowsAiPolicy -Force | Out-Null }
Set-ItemProperty -Path $windowsAiPolicy -Name 'AllowRecallEnablement' -Value 0 -Type DWord
Set-ItemProperty -Path $windowsAiPolicy -Name 'TurnOffSavingSnapshots' -Value 1 -Type DWord

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
Remove-Item -Path "$env:USERPROFILE\.copilot" -Recurse -Force -ErrorAction SilentlyContinue
#endregion

#region OneDrive
# Stop sync client, uninstall all channels, and block reinstall via policy.
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
Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
#endregion

#region Built-in apps > Removal helpers
function Remove-BuiltInApps {
    param([string[]]$PackageNames)
    # Installed (all users + current), then provisioned image packages.
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

function Remove-AppsByPattern {
    param([string[]]$Patterns)
    # Wildcard match on Name / PackageFullName across all removal channels.
    foreach ($pattern in $Patterns) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }

        Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue }

        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
    }
}

function Uninstall-Win32AppByName {
    param([string]$DisplayNamePattern)
    # Walk Uninstall registry keys and run each matching Quiet uninstall string.
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($root in $uninstallRoots) {
        Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            $app = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like $DisplayNamePattern -and $app.UninstallString) {
                $cmd = $app.UninstallString -replace '/I', '/X' -replace '/i', '/x'
                Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd, '/quiet', '/norestart' -Wait -NoNewWindow -ErrorAction SilentlyContinue
            }
        }
    }
}

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
#endregion

#region Built-in apps > Package list
# Remove provisioned + installed Appx for each package name (current user and all users).
Remove-BuiltInApps @(
    'Microsoft.WindowsFeedbackHub'           # Feedback Hub
    'Microsoft.BingWeather'                  # Weather
    'Microsoft.YourPhone'                    # Phone Link
    'MicrosoftCorporationII.MicrosoftFamily' # Family Safety
    'Microsoft.Getstarted'                   # Get Started
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
)

# WhatsApp (Store, Win32 installer, or winget)
Get-Process -Name 'WhatsApp', 'WhatsAppDesktop' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-AppsByPattern @('*WhatsApp*', '*5319275A*')
Uninstall-Win32AppByName '*WhatsApp*'
winget uninstall --name "WhatsApp" --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall --id 5319275A.WhatsAppDesktop --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall --id 9NKSQGP7F2NH --silent --accept-source-agreements --disable-interactivity 2>$null
winget uninstall --id WhatsApp.WhatsApp --silent --accept-source-agreements --disable-interactivity 2>$null
#endregion

#region Remote support tools (optional)
# Interactive: Enter = uninstall, any other key = skip.
$mstsc = Join-Path $env:SystemRoot 'System32\mstsc.exe'
if ((Test-Path $mstsc) -and (Confirm-OptionalUninstall -AppName 'Remote Desktop Connection' -Note 'A restart is required to finish removal. Choose Restart later in the dialog to avoid rebooting now.')) {
    Start-Process -FilePath $mstsc -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
}

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
    Remove-BuiltInApps @('MicrosoftCorporationII.QuickAssist')
    Remove-AppsByPattern @('*QuickAssist*')

    Get-WindowsCapability -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'App.Support.QuickAssist*' -and $_.State -eq 'Installed' } |
        ForEach-Object { Remove-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null }
}
#endregion

#region Taskbar > Unpin all apps (all profiles)
# Clears Quick Launch .lnk pins and Taskband registry for Default + every local user profile.
$userProfiles = @('C:\Users\Default') + (
    Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
    ForEach-Object { $_.FullName }
)

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

foreach ($profileRoot in $userProfiles) {
    $pinnedTaskbar = Join-Path $profileRoot 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    Get-ChildItem -Path $pinnedTaskbar -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq '.lnk' } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $ntuser = Join-Path $profileRoot 'NTUSER.DAT'
    if (-not (Test-Path $ntuser)) { continue }

    $hiveName = "WinSetup_$([guid]::NewGuid().ToString('N'))"
    & reg.exe load "HKU\$hiveName" $ntuser *> $null
    if ($LASTEXITCODE -ne 0) { continue }

    $taskband = "Registry::HKU\$hiveName\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
    foreach ($prop in @('Favorites', 'FavoritesResolve', 'FavoritesChanges', 'FavoritesVersion')) {
        Remove-ItemProperty -Path $taskband -Name $prop -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 200
    & reg.exe unload "HKU\$hiveName" *> $null
}
#endregion

#region Start > Layout (all profiles)
# Empty start2.bin for Default and every user — layout only; HKCU prefs are in Configure.ps1.
$emptyStartLayout = [Convert]::FromBase64String(@'
4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V6aoBj7A+HZAaADAABc9u55LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hwWRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPalSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIOmWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKIaPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCUKZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1TjQ3S6J8tq2yaQ+jFNkxGRMushdXNNiTNjDFYMJNvgRL2lu63NPE+Cxy+IKC1NdKLweFdOGZr2mvKAw7t/fxmCTieUgLkegDomZbHL6anjy4SkjSCnfTBUNtxc0X3VJiha4wq/ArRrTtVnzcUcX+CI4BNTicx+X2eXugI+EHKjgaQS7fXHqQGEUMUeHMCXlgWUZ5kE3LFTjVifyVIGqYNDuqt7T9l7DWByiuRariySa7tiN1gA2ALKYlRsjsQL7xpxHnT1hi/9b+UuyC46cYQaDUcKDc4BGReJP2gDIyZfudLpgUPc7YfH9doiMcWimSylbKFtsI3Mfo0HONxet5XjzjDoziduYk2dFoFfz19uaRcOHtASKzaGdtk6RC+Tm4BbU/7PlbvHEKJZ720AxOQkzU9U8RWAHHsPUVfWzYoQc2dN8OQ/JlUAqe8+PI05ST4m3LoUpBKB+oU0H84aet5etGpIi4CthvazGencFObWJWNRzxk9BXIX2YoAdXB8b7JFwlxVdhgzZK0zkkrzSSmX9iJcNoi6Tp+RtnljzLTAv6xh8gwytIW5F2e5sVh7aiqo4sji0aE+ToqyNPV7eE9Idi2ZNeEbnJ9LX127uOl5jB280hs0caXLUrYiR15+Y31wtlD8JVeTDxDDac6v+e3C4VX+28mg9bYQ7NGYXZc7yZANC/nWTn+/hkTZUvR0gi+PUz4o/DSdKzbvVCAlqdjArcKkWW4r/WKUSLskoOKRPxdNLPVBl2S6blje4LvBzulpeHWubXWfCW4ILuOI
'@)

Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
foreach ($stateDir in @(
    'C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
)) {
    if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
    [IO.File]::WriteAllBytes((Join-Path $stateDir 'start2.bin'), $emptyStartLayout)
}
Get-ChildItem -Path 'C:\Users\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { [IO.File]::WriteAllBytes((Join-Path $_.FullName 'start2.bin'), $emptyStartLayout) }
#endregion

#region Search > Disable web results (system-wide)
# HKLM policies: no Bing/cloud results in Start or taskbar search.
$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
if (-not (Test-Path $searchPolicy)) { New-Item -Path $searchPolicy -Force | Out-Null }
Set-ItemProperty -Path $searchPolicy -Name 'ConnectedSearchUseWeb' -Value 0 -Type DWord
Set-ItemProperty -Path $searchPolicy -Name 'ConnectedSearchUseWebOverMeteredConnections' -Value 0 -Type DWord
Set-ItemProperty -Path $searchPolicy -Name 'DisableWebSearch' -Value 1 -Type DWord

$explorerPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
if (-not (Test-Path $explorerPolicy)) { New-Item -Path $explorerPolicy -Force | Out-Null }
Set-ItemProperty -Path $explorerPolicy -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord
#endregion

#region Apps > Disable consumer experience and Spotlight
# Blocks suggested Store apps, lock screen Spotlight, and related cloud content.
$cloudContentPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
if (-not (Test-Path $cloudContentPolicy)) { New-Item -Path $cloudContentPolicy -Force | Out-Null }
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightOnActionCenter' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightOnSettings' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableThirdPartySuggestions' -Value 1 -Type DWord
#endregion

#region Privacy > Diagnostic data and telemetry (HKLM)
foreach ($dataCollectionPath in @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
)) {
    if (-not (Test-Path $dataCollectionPath)) { New-Item -Path $dataCollectionPath -Force | Out-Null }
    Set-ItemProperty -Path $dataCollectionPath -Name 'AllowTelemetry' -Value 0 -Type DWord
    Set-ItemProperty -Path $dataCollectionPath -Name 'MaxTelemetryAllowed' -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

$dataCollectionPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
Set-ItemProperty -Path $dataCollectionPolicy -Name 'DisableOneSettingsDownloads' -Value 1 -Type DWord
Set-ItemProperty -Path $dataCollectionPolicy -Name 'DoNotShowFeedbackNotifications' -Value 1 -Type DWord

$systemPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
if (-not (Test-Path $systemPolicy)) { New-Item -Path $systemPolicy -Force | Out-Null }
Set-ItemProperty -Path $systemPolicy -Name 'PublishUserActivities' -Value 0 -Type DWord
Set-ItemProperty -Path $systemPolicy -Name 'EnableActivityFeed' -Value 0 -Type DWord
Set-ItemProperty -Path $systemPolicy -Name 'UploadUserActivities' -Value 0 -Type DWord

foreach ($telemetrySvc in @('DiagTrack', 'dmwappushservice')) {
    Set-Service -Name $telemetrySvc -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name $telemetrySvc -Force -ErrorAction SilentlyContinue
}
#endregion

#region Windows Update > Delivery Optimization
# HTTP-only downloads; no peer caching or upload to other PCs.
$deliveryOptimization = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization'
if (-not (Test-Path $deliveryOptimization)) { New-Item -Path $deliveryOptimization -Force | Out-Null }
Set-ItemProperty -Path $deliveryOptimization -Name 'DODownloadMode' -Value 0 -Type DWord

$deliveryOptimizationPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
if (-not (Test-Path $deliveryOptimizationPolicy)) { New-Item -Path $deliveryOptimizationPolicy -Force | Out-Null }
Set-ItemProperty -Path $deliveryOptimizationPolicy -Name 'DODownloadMode' -Value 0 -Type DWord
Set-ItemProperty -Path $deliveryOptimizationPolicy -Name 'DOMaxUploadBandwidth' -Value 0 -Type DWord
Set-ItemProperty -Path $deliveryOptimizationPolicy -Name 'DOPercentageMaxForegroundBandwidth' -Value 0 -Type DWord
Set-ItemProperty -Path $deliveryOptimizationPolicy -Name 'DOPercentageMaxBackgroundBandwidth' -Value 0 -Type DWord
Set-ItemProperty -Path $deliveryOptimizationPolicy -Name 'DOAllowUploadWhileOnBattery' -Value 0 -Type DWord
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Debloat apps applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

#region Shell > Restart Explorer
# Apply taskbar, Start, and pin changes without a full reboot.
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process explorer.exe
#endregion