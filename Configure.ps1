# WinSetup — user-level appearance, shell, and power settings (HKCU).
# Maps to Settings pages where noted. Requires no elevation.
# Run order: Setup.bat → Configure.ps1 → Privacy.ps1 → Debloat.ps1 → Performance.ps1
# Visual effects (sysdm.cpl + Accessibility) live in Performance.ps1.

#region Accessibility > Mouse pointer and motion
# Pointer size 3 only. Color: Setup.bat registers post-reboot Settings prompt at the very end.
$accessibilityPath = 'HKCU:\Software\Microsoft\Accessibility'
$cursorsPath = 'HKCU:\Control Panel\Cursors'
if (-not (Test-Path $accessibilityPath)) { New-Item -Path $accessibilityPath -Force | Out-Null }
Set-ItemProperty -Path $accessibilityPath -Name 'CursorSize' -Value 3 -Type DWord

if (-not (Test-Path $cursorsPath)) { New-Item -Path $cursorsPath -Force | Out-Null }
Set-ItemProperty -Path $cursorsPath -Name 'CursorBaseSize' -Value 64 -Type DWord

Add-Type @'
using System.Runtime.InteropServices;
public static class WinSetupMouse {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
    public const uint SPI_SETMOUSE = 0x0004;
    public const uint SPI_SETCURSORSIZE = 0x2029;
    public const uint SPIF_UPDATEINIFILE = 0x01;
}
'@ -ErrorAction SilentlyContinue

$mousePath = 'HKCU:\Control Panel\Mouse'
Set-ItemProperty -Path $mousePath -Name 'MouseSpeed' -Value '0'
Set-ItemProperty -Path $mousePath -Name 'MouseThreshold1' -Value '0'
Set-ItemProperty -Path $mousePath -Name 'MouseThreshold2' -Value '0'
[void][WinSetupMouse]::SystemParametersInfo([WinSetupMouse]::SPI_SETMOUSE, 0, [int[]]@(0, 0, 0), 0x03)
[void][WinSetupMouse]::SystemParametersInfo([WinSetupMouse]::SPI_SETCURSORSIZE, 0, [uint32]64, [WinSetupMouse]::SPIF_UPDATEINIFILE)

$promptInstaller = Join-Path $PSScriptRoot 'Install-MousePointerPrompt.ps1'
if (Test-Path $promptInstaller) {
    . $promptInstaller
    Remove-WinSetupCursorLegacy
}
#endregion

#region Personalization > Themes > Dark theme
Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
Start-Sleep -Seconds 3
Get-Process -Name "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force
#endregion

#region System > Developer options > End Task
# Right-click taskbar → End task (developer setting).
$TaskbarDevPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
if (-not (Test-Path $TaskbarDevPath)) { New-Item -Path $TaskbarDevPath -Force | Out-Null }
Set-ItemProperty -Path $TaskbarDevPath -Name "TaskbarEndTask" -Value 1 -Type DWord
#endregion

#region Multitasking > Alt + Tab
# Value 3 = open windows only (no browser tabs as separate entries).
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3
#endregion

#region File Explorer > View and navigation
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
# Show file extensions, show hidden files, open to This PC.
Set-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "Hidden" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "LaunchTo" -Value 1 -Type DWord

# Unpin Home and Gallery from the navigation pane.
foreach ($clsid in @(
    '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}', # Home (Inicio)
    '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'  # Gallery (Galería)
)) {
    $clsidPath = "HKCU:\Software\Classes\CLSID\$clsid"
    if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
    Set-ItemProperty -Path $clsidPath -Name 'System.IsPinnedToNameSpaceTree' -Value 0 -Type DWord
}
# Remove legacy shell folders from the user profile (Contacts, Favorites, etc.).
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
        Remove-Item -Path $folderPath -Force -Recurse -ErrorAction SilentlyContinue
    }
}
#endregion

#region Taskbar > Search, grouping, and auto-hide
# Hide the taskbar search box and disable Bing/Cortana integration in search.
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

#endregion

#region Start > Layout and recommendations
# HKCU preferences only — avoid Policies/* keys (they mark Settings as organization-managed).
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
    'SubscribedContent-353696Enabled',
    'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContent-338387Enabled'
)) {
    Set-ItemProperty -Path $contentDelivery -Name $name -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

# Local search only: disable cloud/Bing results in Start Menu
$searchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
if (-not (Test-Path $searchSettings)) { New-Item -Path $searchSettings -Force | Out-Null }
Set-ItemProperty -Path $searchSettings -Name 'IsMSACloudSearchEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $searchSettings -Name 'IsAADCloudSearchEnabled' -Value 0 -Type DWord
# Empty start2.bin for all profiles is applied in Debloat.ps1 (elevated).
#endregion

#region System > Power > Screen and sleep
# Display off after 3 minutes; sleep disabled on AC and battery.
powercfg /change monitor-timeout-ac 3 | Out-Null
powercfg /change monitor-timeout-dc 3 | Out-Null
powercfg /change standby-timeout-ac 0 | Out-Null
powercfg /change standby-timeout-dc 0 | Out-Null
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Configuration settings applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
