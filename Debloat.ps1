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

#region Disable Fast Startup
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord
#endregion

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
Remove-Item -Path "$env:USERPROFILE\.copilot" -Recurse -Force -ErrorAction SilentlyContinue
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
Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
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

function Remove-AppsByPattern {
    param([string[]]$Patterns)

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

# Get Started (embedded in MicrosoftWindows.Client.CBS; cannot be safely removed)
Remove-AppsByPattern @('*Getstarted*', '*StartExperiencesApp*')
#endregion

#region Remote support tools (optional uninstall)
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

#region Taskbar: unpin all apps for all profiles
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

#region Start Menu
# Layout only: apply empty start2.bin to all user profiles (requires admin). Registry prefs are in Configure.ps1.
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

#region Start Menu search: disable Bing/web results (system-wide)
$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
if (-not (Test-Path $searchPolicy)) { New-Item -Path $searchPolicy -Force | Out-Null }
Set-ItemProperty -Path $searchPolicy -Name 'ConnectedSearchUseWeb' -Value 0 -Type DWord
Set-ItemProperty -Path $searchPolicy -Name 'ConnectedSearchUseWebOverMeteredConnections' -Value 0 -Type DWord
Set-ItemProperty -Path $searchPolicy -Name 'DisableWebSearch' -Value 1 -Type DWord

$explorerPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
if (-not (Test-Path $explorerPolicy)) { New-Item -Path $explorerPolicy -Force | Out-Null }
Set-ItemProperty -Path $explorerPolicy -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord
#endregion

#region Disable automatic installation of apps
# HKLM: "Turn off Microsoft consumer experiences" (blocks suggested apps system-wide)
$cloudContentPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
if (-not (Test-Path $cloudContentPolicy)) { New-Item -Path $cloudContentPolicy -Force | Out-Null }
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Debloat apps applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

#region Restart Explorer to apply changes
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process explorer.exe
#endregion