#region Accessibility > Mouse pointer and motion
Write-Host '[*] Mouse pointer and motion...' -ForegroundColor DarkGray
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
Write-Host '[*] Dark theme...' -ForegroundColor DarkGray
Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
Start-Sleep -Seconds 3
Get-Process -Name "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force
#endregion

#region System > Developer options > End Task
Write-Host '[*] Taskbar End task...' -ForegroundColor DarkGray
$TaskbarDevPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
if (-not (Test-Path $TaskbarDevPath)) { New-Item -Path $TaskbarDevPath -Force | Out-Null }
Set-ItemProperty -Path $TaskbarDevPath -Name "TaskbarEndTask" -Value 1 -Type DWord
#endregion

#region Multitasking > Alt + Tab
Write-Host '[*] Alt+Tab: open windows only...' -ForegroundColor DarkGray
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3
#endregion

#region File Explorer > View and navigation
Write-Host '[*] File Explorer view and navigation...' -ForegroundColor DarkGray
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "Hidden" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "LaunchTo" -Value 1 -Type DWord

foreach ($clsid in @(
    '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}',
    '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
)) {
    $clsidPath = "HKCU:\Software\Classes\CLSID\$clsid"
    if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
    Set-ItemProperty -Path $clsidPath -Name 'System.IsPinnedToNameSpaceTree' -Value 0 -Type DWord
}
$userDirectory = "$env:USERPROFILE\"
$unusedFolders = @('Contacts', 'Favorites', 'Links', 'Saved Games', 'Searches')
foreach ($folder in $unusedFolders) {
    $folderPath = Join-Path $userDirectory $folder
    if (Test-Path $folderPath) {
        Remove-Item -Path $folderPath -Force -Recurse -ErrorAction SilentlyContinue
    }
}
#endregion

#region Taskbar > Search, grouping, and auto-hide
Write-Host '[*] Taskbar search, grouping, auto-hide...' -ForegroundColor DarkGray
$SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarModeCache" -Value 1 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "IsEnabled" -Value 0 -Type DWord

Set-ItemProperty -Path $ExplorerPath -Name "MMTaskbarEnabled" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "MMTaskbarMode" -Value 2 -Type DWord

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
Write-Host '[*] Start layout and recommendations...' -ForegroundColor DarkGray
$startPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
if (-not (Test-Path $startPath)) { New-Item -Path $startPath -Force | Out-Null }
Set-ItemProperty -Path $startPath -Name 'AllAppsViewMode' -Value 1 -Type DWord
Set-ItemProperty -Path $startPath -Name 'ShowRecentList' -Value 0 -Type DWord
Set-ItemProperty -Path $startPath -Name 'ShowFrequentList' -Value 0 -Type DWord

$visiblePlaces = @(
    [guid]'52730886-51AA-4243-9F7B-2776584659D4',
    [guid]'148A24BC-D60C-4289-A080-6ED9BBA24882',
    [guid]'74BDB04A-F94A-4F68-8BD6-4398071DA8BC'
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

$searchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
if (-not (Test-Path $searchSettings)) { New-Item -Path $searchSettings -Force | Out-Null }
Set-ItemProperty -Path $searchSettings -Name 'IsMSACloudSearchEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $searchSettings -Name 'IsAADCloudSearchEnabled' -Value 0 -Type DWord
#endregion

#region System > Power > Screen and sleep
Write-Host '[*] Power: display timeout, sleep off...' -ForegroundColor DarkGray
powercfg /change monitor-timeout-ac 3 | Out-Null
powercfg /change monitor-timeout-dc 3 | Out-Null
powercfg /change standby-timeout-ac 0 | Out-Null
powercfg /change standby-timeout-dc 0 | Out-Null
#endregion

exit 0
