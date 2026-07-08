#region Dark Theme
Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
Start-Sleep -Seconds 3
Get-Process -Name "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force
#endregion

#region Disable Transparency Effects
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0
#endregion

#region Disable Animation Effects (Accessibility > Visual effects)
$desktopPath = 'HKCU:\Control Panel\Desktop'
$metricsPath = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$mask = (Get-ItemProperty -Path $desktopPath).UserPreferencesMask.Clone()
$mask[0] = $mask[0] -band (-bnot 0x0E)
$mask[1] = $mask[1] -band (-bnot 0x0C)
$mask[4] = $mask[4] -band (-bnot 0x02)
Set-ItemProperty -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value $mask
Set-ItemProperty -Path $metricsPath -Name 'MinAnimate' -Value '0'
#endregion

#region Enable End Task (End Task in Taskbar)
$TaskbarDevPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
if (-not (Test-Path $TaskbarDevPath)) { New-Item -Path $TaskbarDevPath -Force | Out-Null }
Set-ItemProperty -Path $TaskbarDevPath -Name "TaskbarEndTask" -Value 1 -Type DWord
#endregion

#region Multi Task: No show browser tabs in Alt + Tab
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3
#endregion

#region File Explorer
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "Hidden" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "LaunchTo" -Value 1 -Type DWord

foreach ($clsid in @(
    '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}', # Home (Inicio)
    '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'  # Gallery (Galería)
)) {
    $clsidPath = "HKCU:\Software\Classes\CLSID\$clsid"
    if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
    Set-ItemProperty -Path $clsidPath -Name 'System.IsPinnedToNameSpaceTree' -Value 0 -Type DWord
}
# Remove unused folders from user's directory
$userDirectory = "$env:USERPROFILE\"
$unusedFolders = @(
    'Contacts',
    'Favorites',
    'Links',
    'Saved Games',
    'Searches'
)
foreach ($folder in $unusedFolders) {
    $folderPath = Join-Path $userDirectory $folder
    if (Test-Path $folderPath) {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
#endregion

#region Taskbar
# Hide search box
$SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarModeCache" -Value 1 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "IsEnabled" -Value 0 -Type DWord

# Multi-monitor: app icons only on the taskbar where the window is open
Set-ItemProperty -Path $ExplorerPath -Name "MMTaskbarEnabled" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "MMTaskbarMode" -Value 2 -Type DWord

# Auto-hide taskbar (StuckRects3 byte 8: 2=visible, 3=auto-hide)
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$stuckRects = Join-Path $explorerKey 'StuckRects3'
if (Test-Path $stuckRects) {
    $taskbarSettings = (Get-ItemProperty -Path $stuckRects -Name Settings).Settings.Clone()
    $taskbarSettings[8] = 3
    Set-ItemProperty -Path $stuckRects -Name Settings -Type Binary -Value $taskbarSettings
}
$mmStuckRects = Join-Path $explorerKey 'MMStuckRects3'
if (Test-Path $mmStuckRects) {
    Get-ItemProperty -Path $mmStuckRects |
        Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -notmatch '^PS' } |
        ForEach-Object {
            $monitorSettings = (Get-ItemProperty -Path $mmStuckRects -Name $_.Name).($_.Name).Clone()
            if ($monitorSettings.Length -gt 8) {
                $monitorSettings[8] = 3
                Set-ItemProperty -Path $mmStuckRects -Name $_.Name -Type Binary -Value $monitorSettings
            }
        }
}

# Unpin all apps (shortcuts + Taskband cache; explorer restart at end of script)
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$pinnedTaskbar = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
Get-ChildItem -Path $pinnedTaskbar -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.lnk' } |
    Remove-Item -Force -ErrorAction SilentlyContinue

$taskband = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
foreach ($prop in @('Favorites', 'FavoritesResolve', 'FavoritesChanges', 'FavoritesVersion')) {
    Remove-ItemProperty -Path $taskband -Name $prop -ErrorAction SilentlyContinue
}
#endregion

#region Start Menu
# User preferences only (no Policies/* keys — those lock Settings as "managed by organization")
$startPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
if (-not (Test-Path $startPath)) { New-Item -Path $startPath -Force | Out-Null }
Set-ItemProperty -Path $startPath -Name 'AllAppsViewMode' -Value 1 -Type DWord
Set-ItemProperty -Path $startPath -Name 'ShowRecentList' -Value 0 -Type DWord
Set-ItemProperty -Path $startPath -Name 'ShowFrequentList' -Value 0 -Type DWord

# Folders next to power button: Settings, File Explorer, Personal folder
$visiblePlaces = @(
    [guid]'52730886-51AA-4243-9F7B-2776584659D4' # Settings
    [guid]'148A24BC-D60C-4289-A080-6ED9BBA24882' # File Explorer
    [guid]'74BDB04A-F94A-4F68-8BD6-4398071DA8BC' # Personal folder
)
$visiblePlacesBytes = New-Object byte[] ($visiblePlaces.Count * 16)
for ($i = 0; $i -lt $visiblePlaces.Count; $i++) {
    [Array]::Copy($visiblePlaces[$i].ToByteArray(), 0, $visiblePlacesBytes, $i * 16, 16)
}
Set-ItemProperty -Path $startPath -Name 'VisiblePlaces' -Type Binary -Value $visiblePlacesBytes
Set-ItemProperty -Path $startPath -Name 'PlacesInitializedVersion' -Value 2 -Type DWord

Set-ItemProperty -Path $ExplorerPath -Name 'Start_IrisRecommendations' -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name 'Start_TrackProgs' -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name 'Start_TrackDocs' -Value 0 -Type DWord
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowRecent' -Value 0 -Type DWord

$contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
foreach ($name in @(
    'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled',
    'ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
    'SubscribedContent-338388Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled',
    'SubscribedContent-353696Enabled'
)) {
    Set-ItemProperty -Path $contentDelivery -Name $name -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

# Local search only: disable cloud/Bing results in Start Menu
$searchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
if (-not (Test-Path $searchSettings)) { New-Item -Path $searchSettings -Force | Out-Null }
Set-ItemProperty -Path $searchSettings -Name 'IsMSACloudSearchEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $searchSettings -Name 'IsAADCloudSearchEnabled' -Value 0 -Type DWord

# Replace start2.bin with empty layout (deleting it restores OEM defaults with pins)
$emptyStartLayout = [Convert]::FromBase64String(@'
4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V6aoBj7A+HZAaADAABc9u55LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hwWRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPalSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIOmWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKIaPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCUKZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1TjQ3S6J8tq2yaQ+jFNkxGRMushdXNNiTNjDFYMJNvgRL2lu63NPE+Cxy+IKC1NdKLweFdOGZr2mvKAw7t/fxmCTieUgLkegDomZbHL6anjy4SkjSCnfTBUNtxc0X3VJiha4wq/ArRrTtVnzcUcX+CI4BNTicx+X2eXugI+EHKjgaQS7fXHqQGEUMUeHMCXlgWUZ5kE3LFTjVifyVIGqYNDuqt7T9l7DWByiuRariySa7tiN1gA2ALKYlRsjsQL7xpxHnT1hi/9b+UuyC46cYQaDUcKDc4BGReJP2gDIyZfudLpgUPc7YfH9doiMcWimSylbKFtsI3Mfo0HONxet5XjzjDoziduYk2dFoFfz19uaRcOHtASKzaGdtk6RC+Tm4BbU/7PlbvHEKJZ720AxOQkzU9U8RWAHHsPUVfWzYoQc2dN8OQ/JlUAqe8+PI05ST4m3LoUpBKB+oU0H84aet5etGpIi4CthvazGencFObWJWNRzxk9BXIX2YoAdXB8b7JFwlxVdhgzZK0zkkrzSSmX9iJcNoi6Tp+RtnljzLTAv6xh8gwytIW5F2e5sVh7aiqo4sji0aE+ToqyNPV7eE9Idi2ZNeEbnJ9LX127uOl5jB280hs0caXLUrYiR15+Y31wtlD8JVeTDxDDac6v+e3C4VX+28mg9bYQ7NGYXZc7yZANC/nWTn+/hkTZUvR0gi+PUz4o/DSdKzbvVCAlqdjArcKkWW4r/WKUSLskoOKRPxdNLPVBl2S6blje4LvBzulpeHWubXWfCW4ILuOI
'@)

$startMenuState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
if (-not (Test-Path $startMenuState)) { New-Item -Path $startMenuState -ItemType Directory -Force | Out-Null }
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
[IO.File]::WriteAllBytes((Join-Path $startMenuState 'start2.bin'), $emptyStartLayout)
#endregion

#region Mouse
# Accessibility > Mouse pointer: Turquoise preset, size 3 (slider 1-15; base size 64 px)
# Color is baked into *_eoa.cur files. Windows may regenerate white cursors at logon;
# Apply-Cursor.ps1 is deployed to %LOCALAPPDATA%\WinSetup\ and runs at sign-in.
$userCursorDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$cursorStore = Join-Path $env:LOCALAPPDATA 'WinSetup\Cursors'
$winSetupDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
$cursorReleaseUrl = 'https://github.com/Leviatan1121/WinSetup/releases/latest/download/Cursors.zip'

if (-not (Test-Path $userCursorDir)) { New-Item -Path $userCursorDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $cursorStore)) { New-Item -Path $cursorStore -ItemType Directory -Force | Out-Null }

$cursorZip = @(
    (Join-Path $PSScriptRoot 'Cursors.zip')
    (Join-Path $PSScriptRoot 'Assets\Cursors.zip')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $cursorZip) {
    $cursorZip = Join-Path $PSScriptRoot 'Cursors.zip'
    try {
        Invoke-RestMethod -Uri $cursorReleaseUrl -OutFile $cursorZip
    } catch {
        Write-Warning "Mouse pointer color: could not download Cursors.zip ($cursorReleaseUrl)."
        $cursorZip = $null
    }
}

if ($cursorZip -and (Test-Path $cursorZip)) {
    Expand-Archive -Path $cursorZip -DestinationPath $cursorStore -Force
    Get-ChildItem -Path $cursorStore -Filter '*.cur' -ErrorAction SilentlyContinue |
        Copy-Item -Destination $userCursorDir -Force

    $repoZip = Join-Path $PSScriptRoot 'Assets\Cursors.zip'
    if ($cursorZip -ne $repoZip) {
        Remove-Item $cursorZip -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Warning 'Mouse pointer color: Cursors.zip not found. Run Assets\Export-CursorAssets.ps1 after selecting turquoise in Settings.'
}

if (-not (Test-Path $winSetupDir)) { New-Item -Path $winSetupDir -ItemType Directory -Force | Out-Null }
$applyCursorSrc = Join-Path $PSScriptRoot 'Apply-Cursor.ps1'
$applyCursorDst = Join-Path $winSetupDir 'Apply-Cursor.ps1'
if (Test-Path $applyCursorSrc) {
    Copy-Item -Path $applyCursorSrc -Destination $applyCursorDst -Force
} else {
    $applyReleaseUrl = 'https://github.com/Leviatan1121/WinSetup/releases/latest/download/Apply-Cursor.ps1'
    try {
        Invoke-RestMethod -Uri $applyReleaseUrl -OutFile $applyCursorDst
    } catch {
        Write-Warning "Mouse pointer color: could not download Apply-Cursor.ps1 ($applyReleaseUrl)."
    }
}

if (Test-Path $applyCursorDst) {
    & $applyCursorDst

    $taskName = 'WinSetup-ApplyCursor'
    $taskArgument = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$applyCursorDst`""
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgument
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
    } catch {
        $startupPath = [Environment]::GetFolderPath('Startup')
        $launcherVbs = Join-Path $startupPath 'WinSetup-ApplyCursor.vbs'
        $vbsContent = "CreateObject(""Wscript.Shell"").Run ""powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """"""$applyCursorDst"""""""", 0, False"
        Set-Content -Path $launcherVbs -Value $vbsContent -Encoding ASCII
        Write-Warning "Could not register logon task ($($_.Exception.Message)); using Startup shortcut instead."
    }
}
#endregion

#region Power
# Turn off display after 3 minutes (AC and battery); no sleep on AC or battery
powercfg /change monitor-timeout-ac 3 | Out-Null
powercfg /change monitor-timeout-dc 3 | Out-Null
powercfg /change standby-timeout-ac 0 | Out-Null
powercfg /change standby-timeout-dc 0 | Out-Null
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Configuration settings applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan