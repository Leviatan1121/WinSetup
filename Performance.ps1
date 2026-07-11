# WinSetup — visual performance preset (sysdm.cpl + Accessibility > Visual effects).
# HKCU by default; -SystemOnly for HKLM tweaks (called from WinSetup.ps1 elevated child).
# Run order: WinSetup.ps1 → Configure → Privacy → Performance (user) → Performance -SystemOnly → pointer hooks

param([switch]$SystemOnly)

#region Performance Options > Advanced > Processor scheduling and MMCSS (HKLM)
if ($SystemOnly) {
    $priorityPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    $mmcssPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    $gameDvrPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'

    Set-ItemProperty -Path $priorityPath -Name 'Win32PrioritySeparation' -Value 38 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mmcssPath -Name 'SystemResponsiveness' -Value 0 -Type DWord
    Set-ItemProperty -Path $mmcssPath -Name 'NetworkThrottlingIndex' -Value 0xFFFFFFFF -Type DWord
    if (-not (Test-Path $gameDvrPolicy)) { New-Item -Path $gameDvrPolicy -Force | Out-Null }
    Set-ItemProperty -Path $gameDvrPolicy -Name 'AllowGameDVR' -Value 0 -Type DWord

    Write-Host '=========================================================' -ForegroundColor Cyan
    Write-Host '[!] Performance (system) applied.' -ForegroundColor Cyan
    Write-Host '=========================================================' -ForegroundColor Cyan
    exit 0
}
#endregion

# Usage: AllowFile.bat .\Performance.ps1
#
# sysdm.cpl: custom preset — best performance + Explorer thumbnails + ClearType.
# Accessibility: Animation effects OFF, Transparency effects OFF.
# Gaming: background DVR + Game Mode OFF (OBS workflow); Win+G Game Bar overlay kept.
# After running: sign out and back in (or reboot) before verifying in sysdm.cpl.

#region Paths
$visualEffectsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
$desktopPath = 'HKCU:\Control Panel\Desktop'
$metricsPath = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$dwmPath = 'HKCU:\Software\Microsoft\Windows\DWM'
$explorerAdvanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

if (-not (Test-Path $visualEffectsPath)) { New-Item -Path $visualEffectsPath -Force | Out-Null }
if (-not (Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }
#endregion

#region Performance Options > Step 1: Best performance baseline
# Official "Adjust for best performance" — resets the preset before custom tweaks.
Set-ItemProperty -Path $visualEffectsPath -Name 'VisualFXSetting' -Value 2 -Type DWord
$bestPerfMask = [byte[]](0x9E, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
Set-ItemProperty -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value $bestPerfMask
Set-ItemProperty -Path $metricsPath -Name 'MinAnimate' -Value '0' -Type String
#endregion

#region Accessibility > Visual effects
# Settings: ms-settings:easeofaccess-visualeffects

# Transparency effects → Off (also listed under Personalization > Colors on some builds)
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type DWord

# Animation effects → Off (UserPreferencesMask bytes 0, 1, 4 + MinAnimate; user capture on Win11)
$mask = (Get-ItemProperty -Path $desktopPath).UserPreferencesMask.Clone()
$mask[0] = $mask[0] -band (-bnot 0x0E)
$mask[1] = $mask[1] -band (-bnot 0x0C)
$mask[4] = $mask[4] -band (-bnot 0x02)
Set-ItemProperty -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value $mask
Set-ItemProperty -Path $metricsPath -Name 'MinAnimate' -Value '0' -Type String
#endregion

#region Performance Options > Step 2: Disable non-mask settings
Set-ItemProperty -Path $desktopPath -Name 'DragFullWindows' -Value '0' -Type String
Set-ItemProperty -Path $explorerAdvanced -Name 'TaskbarAnimations' -Value 0 -Type DWord
Set-ItemProperty -Path $explorerAdvanced -Name 'ListviewAlphaSelect' -Value 0 -Type DWord
Set-ItemProperty -Path $explorerAdvanced -Name 'ListviewShadow' -Value 0 -Type DWord
Set-ItemProperty -Path $explorerAdvanced -Name 'DisablePreviewDesktop' -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwmPath -Name 'AlwaysHibernateThumbnails' -Value 0 -Type DWord
Set-ItemProperty -Path $dwmPath -Name 'EnableAeroPeek' -Value 0 -Type DWord
#endregion

#region Performance Options > Step 3: Enable thumbnails + ClearType
Set-ItemProperty -Path $explorerAdvanced -Name 'IconsOnly' -Value 0 -Type DWord
Set-ItemProperty -Path $desktopPath -Name 'FontSmoothing' -Value '2' -Type String
Set-ItemProperty -Path $desktopPath -Name 'FontSmoothingType' -Value 2 -Type DWord
#endregion

#region Performance Options > Step 4: Custom mask (only font-smoothing bit added to perf+anim-off base)
# Expected: 90 12 03 80 10 02 00 00 (or 90 12 07 80 10 02 if byte2 differs on this profile).
$mask = (Get-ItemProperty -Path $desktopPath).UserPreferencesMask.Clone()
$mask[5] = 0x02
Set-ItemProperty -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value $mask
Set-ItemProperty -Path $visualEffectsPath -Name 'VisualFXSetting' -Value 3 -Type DWord
#endregion

#region Gaming > Game DVR, Game Mode (HKCU); Game Bar overlay (Win+G) kept
# Background capture + Game Mode OFF for OBS + Discord + VTube Studio.
# Do not disable UseNexusForGameBarEnabled — Win+G overlay stays available.
$gameConfigStore = 'HKCU:\System\GameConfigStore'
if (-not (Test-Path $gameConfigStore)) { New-Item -Path $gameConfigStore -Force | Out-Null }
Set-ItemProperty -Path $gameConfigStore -Name 'GameDVR_Enabled' -Value 0 -Type DWord

$gameDvrPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
if (-not (Test-Path $gameDvrPath)) { New-Item -Path $gameDvrPath -Force | Out-Null }
Set-ItemProperty -Path $gameDvrPath -Name 'AppCaptureEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $gameDvrPath -Name 'HistoricalCaptureEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue

$gameBarPath = 'HKCU:\Software\Microsoft\GameBar'
if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
Set-ItemProperty -Path $gameBarPath -Name 'AllowAutoGameMode' -Value 0 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name 'AutoGameModeEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name 'ShowStartupPanel' -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $gameBarPath -Name 'UseNexusForGameBarEnabled' -Value 1 -Type DWord -ErrorAction SilentlyContinue
#endregion

#region Apply changes
if (-not ('WinSetup.PerfNotify' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace WinSetup {
    public static class PerfNotify {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint msg, UIntPtr wParam, string lParam,
            uint flags, uint timeout, out UIntPtr result);
    }
}
'@
}

$nullResult = [UIntPtr]::Zero
[void][WinSetup.PerfNotify]::SendMessageTimeout(
    [IntPtr]0xFFFF, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$nullResult)
#endregion

#region Report
Write-Host '[+] Performance (user) applied.' -ForegroundColor Green
exit 0
#endregion
