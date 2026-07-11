param([switch]$WinSetupElevated)

. (Join-Path $PSScriptRoot 'WinSetup-WingetHelpers.ps1')

#region Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($WinSetupElevated) {
    if (-not $isAdmin) {
        Write-Error 'Debloat.ps1 -WinSetupElevated requires an administrator session.'
        exit 1
    }
} elseif (-not $isAdmin) {
    if (-not $PSCommandPath) {
        Write-Error 'Debloat.ps1 must be run from a file (e.g. WinSetup.ps1 or AllowFile.bat).'
        exit 1
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit $LASTEXITCODE
}
#endregion

#region System > Power > Fast startup
Write-Host '[*] Disabling fast startup...' -ForegroundColor DarkGray
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord
#endregion

#region Privacy > Location (elevated)
Write-Host '[*] Disabling system location...' -ForegroundColor DarkGray
$adminFlows = Join-Path $env:WINDIR 'System32\SystemSettingsAdminFlows.exe'
if (Test-Path $adminFlows) {
    & $adminFlows SetCamSystemGlobal location 1 | Out-Null
    Start-Sleep -Milliseconds 400
    & $adminFlows SetCamSystemGlobal location 0 | Out-Null
    & $adminFlows SetGeolocationMaster 1 | Out-Null
    Start-Sleep -Milliseconds 400
    & $adminFlows SetGeolocationMaster 0 | Out-Null
}

$locationPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
if (-not (Test-Path $locationPolicy)) { New-Item -Path $locationPolicy -Force | Out-Null }
Set-ItemProperty -Path $locationPolicy -Name 'DisableLocation' -Value 1 -Type DWord

$locationHklm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
if (-not (Test-Path $locationHklm)) { New-Item -Path $locationHklm -Force | Out-Null }
Set-ItemProperty -Path $locationHklm -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationHklm -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

$locationNonPackagedHklm = Join-Path $locationHklm 'NonPackaged'
if (-not (Test-Path $locationNonPackagedHklm)) { New-Item -Path $locationNonPackagedHklm -Force | Out-Null }
Set-ItemProperty -Path $locationNonPackagedHklm -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationNonPackagedHklm -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

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
Write-Host '[*] Removing taskbar widgets...' -ForegroundColor DarkGray
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

Invoke-WinSetupWingetUninstall --id 9MSSGKG348SP --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --name "Windows Web Experience Pack" --silent --accept-source-agreements --disable-interactivity

Get-AppxPackage -Name "Microsoft.WidgetsPlatformRuntime" -ErrorAction SilentlyContinue |
    Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage -AllUsers -Name "Microsoft.WidgetsPlatformRuntime" -ErrorAction SilentlyContinue |
    Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object DisplayName -Like '*WidgetsPlatformRuntime*' |
    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
Invoke-WinSetupWingetUninstall --name "Widgets Platform Runtime" --silent --accept-source-agreements --disable-interactivity
#endregion

#region Copilot, Recall, and integrated AI
$aiScriptPath = Join-Path $PSScriptRoot 'WinSetup-AI-UpdateCleanup.ps1'
if (Test-Path -LiteralPath $aiScriptPath) {
    try {
        . $aiScriptPath
        Initialize-WinSetupAI
    } catch {
        Write-Warning "AI removal failed: $($_.Exception.Message)"
    }
} else {
    Write-Warning 'WinSetup-AI-UpdateCleanup.ps1 not found - skipping AI removal.'
}
#endregion

#region OneDrive
Write-Host '[*] Removing OneDrive...' -ForegroundColor DarkGray
Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Invoke-WinSetupWingetUninstall --name "Microsoft OneDrive" --silent --accept-source-agreements --disable-interactivity

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

function Remove-PythonAppExecutionAliases {
    param(
        [string]$ProfileRoot
    )

    $windowsApps = Join-Path $ProfileRoot 'AppData\Local\Microsoft\WindowsApps'
    if (-not (Test-Path -LiteralPath $windowsApps)) {
        return
    }

    foreach ($aliasName in @('python.exe', 'python3.exe')) {
        $aliasPath = Join-Path $windowsApps $aliasName
        if (-not (Test-Path -LiteralPath $aliasPath)) {
            continue
        }

        $item = Get-Item -LiteralPath $aliasPath -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            & fsutil.exe reparsePoint delete $aliasPath 2>$null | Out-Null
        }

        if (Test-Path -LiteralPath $aliasPath) {
            Remove-Item -LiteralPath $aliasPath -Force -ErrorAction SilentlyContinue
        }
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
#endregion

#region Built-in apps > Package list
Write-Host '[*] Removing built-in apps...' -ForegroundColor DarkGray
Remove-BuiltInApps @(
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.BingWeather',
    'Microsoft.YourPhone',
    'MicrosoftCorporationII.MicrosoftFamily',
    'Microsoft.Getstarted',
    'Microsoft.StartExperiencesApp',
    'Microsoft.MicrosoftJournal',
    'Microsoft.MicrosoftOfficeHub',
    'Clipchamp.Clipchamp',
    'MicrosoftTeams',
    'MSTeams',
    'Microsoft.Teams',
    'Microsoft.Todos',
    'Microsoft.Whiteboard',
    'Microsoft.MicrosoftStickyNotes',
    'Microsoft.BingNews',
    'Microsoft.BingSearch',
    'Microsoft.Windows.DevHome',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.OutlookForWindows',
    'Microsoft.OneConnect',
    'Microsoft.MicrosoftSolitaireCollection'
)

Get-Process -Name 'WhatsApp', 'WhatsAppDesktop' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-AppsByPattern @('*WhatsApp*', '*5319275A*')
Uninstall-Win32AppByName '*WhatsApp*'
Invoke-WinSetupWingetUninstall --name "WhatsApp" --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --id 5319275A.WhatsAppDesktop --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --id 9NKSQGP7F2NH --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --id WhatsApp.WhatsApp --silent --accept-source-agreements --disable-interactivity

Invoke-WinSetupWingetUninstall --id 9NZBF4GT040C --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --name "Microsoft Bing" --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --name "Dev Home" --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --id 9NFTCH6J7FHV --silent --accept-source-agreements --disable-interactivity
Invoke-WinSetupWingetUninstall --name "Power Automate" --silent --accept-source-agreements --disable-interactivity
#endregion

#region Taskbar > Unpin all apps (all profiles)
Write-Host '[*] Unpinning taskbar apps (all profiles)...' -ForegroundColor DarkGray
$userProfiles = @('C:\Users\Default') + (
    Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
    ForEach-Object { $_.FullName }
)

Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
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
Write-Host '[*] Resetting Start layout (all profiles)...' -ForegroundColor DarkGray
$emptyStartLayout = [Convert]::FromBase64String(@'
4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V6aoBj7A+HZAaADAABc9u55LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hwWRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPalSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIOmWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKIaPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCUKZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1TjQ3S6J8tq2yaQ+jFNkxGRMushdXNNiTNjDFYMJNvgRL2lu63NPE+Cxy+IKC1NdKLweFdOGZr2mvKAw7t/fxmCTieUgLkegDomZbHL6anjy4SkjSCnfTBUNtxc0X3VJiha4wq/ArRrTtVnzcUcX+CI4BNTicx+X2eXugI+EHKjgaQS7fXHqQGEUMUeHMCXlgWUZ5kE3LFTjVifyVIGqYNDuqt7T9l7DWByiuRariySa7tiN1gA2ALKYlRsjsQL7xpxHnT1hi/9b+UuyC46cYQaDUcKDc4BGReJP2gDIyZfudLpgUPc7YfH9doiMcWimSylbKFtsI3Mfo0HONxet5XjzjDoziduYk2dFoFfz19uaRcOHtASKzaGdtk6RC+Tm4BbU/7PlbvHEKJZ720AxOQkzU9U8RWAHHsPUVfWzYoQc2dN8OQ/JlUAqe8+PI05ST4m3LoUpBKB+oU0H84aet5etGpIi4CthvazGencFObWJWNRzxk9BXIX2YoAdXB8b7JFwlxVdhgzZK0zkkrzSSmX9iJcNoi6Tp+RtnljzLTAv6xh8gwytIW5F2e5sVh7aiqo4sji0aE+ToqyNPV7eE9Idi2ZNeEbnJ9LX127uOl5jB280hs0caXLUrYiR15+Y31wtlD8JVeTDxDDac6v+e3C4VX+28mg9bYQ7NGYXZc7yZANC/nWTn+/hkTZUvR0gi+PUz4o/DSdKzbvVCAlqdjArcKkWW4r/WKUSLskoOKRPxdNLPVBl2S6blje4LvBzulpeHWubXWfCW4ILuOI
'@)

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
Write-Host '[*] Disabling web search results...' -ForegroundColor DarkGray
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
Write-Host '[*] Disabling consumer experience and Spotlight...' -ForegroundColor DarkGray
$cloudContentPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
if (-not (Test-Path $cloudContentPolicy)) { New-Item -Path $cloudContentPolicy -Force | Out-Null }
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightOnActionCenter' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableWindowsSpotlightOnSettings' -Value 1 -Type DWord
Set-ItemProperty -Path $cloudContentPolicy -Name 'DisableThirdPartySuggestions' -Value 1 -Type DWord
#endregion

#region Apps > Disable Microsoft Store Python execution aliases
Write-Host '[*] Disabling Store Python aliases...' -ForegroundColor DarkGray
$pythonAliasProfiles = @('C:\Users\Default') + (
    Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
    ForEach-Object { $_.FullName }
)

foreach ($profileRoot in $pythonAliasProfiles) {
    Remove-PythonAppExecutionAliases -ProfileRoot $profileRoot
}
#endregion

#region Privacy > Diagnostic data and telemetry (HKLM)
Write-Host '[*] Reducing telemetry (HKLM)...' -ForegroundColor DarkGray
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
Write-Host '[*] Disabling Delivery Optimization peer cache...' -ForegroundColor DarkGray
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

exit 0
