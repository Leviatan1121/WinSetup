# WinSetup — apply Settings > Accessibility > Mouse pointer (size, style, custom color).
# Dot-source from Configure.ps1 or run directly: AllowFile.bat .\Set-MousePointer.ps1
# Custom color (type 6) requires *_eoa.cur — from Cursors.zip or %LocalAppData%\WinSetup\Cursors.

#region Preferences
# PointerType: 1 white, 2 black, 3 inverted, 6 custom (CursorColor).
# PointerSize: 1–4; 3 → 64px, 4 → 80px.
$script:PointerSize = 3
$script:PointerColor = 16760576 # COLORREF 0x00FFBF00 (turquoise). Pure blue: 16711680 (0x00FF0000).
$script:PointerType = 6
#endregion

function Set-WinSetupMousePointer {
    [CmdletBinding()]
    param(
        [string]$CursorsZip
    )

    $persistDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    $persistCursors = Join-Path $persistDir 'Cursors'
    $persistZip = Join-Path $persistDir 'Cursors.zip'

    if (-not $CursorsZip) {
        foreach ($candidate in @(
            (Join-Path $PSScriptRoot 'Cursors.zip'),
            $persistZip
        )) {
            if (Test-Path $candidate) {
                $CursorsZip = $candidate
                break
            }
        }
    }

    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' `
        -Name 'ThemeChangesMousePointers' -Value 0 -Type DWord -ErrorAction SilentlyContinue

    if (-not ('WinSetupInput' -as [type])) {
        Add-Type @'
using System.Runtime.InteropServices;
public static class WinSetupInput {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
    public const uint SPI_SETCURSORS = 0x0057;
    public const uint SPI_SETCURSORSIZE = 0x2029;
    public const uint SPIF_UPDATEINIFILE = 0x01;
    public const uint SPIF_SENDCHANGE = 0x02;
}
'@
    }

    $accessibilityPath = 'HKCU:\Software\Microsoft\Accessibility'
    $cursorsPath = 'HKCU:\Control Panel\Cursors'
    $userCursorDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
    $cursorBaseSize = if ($script:PointerSize -ge 4) { 80 } else { 64 }

    if (-not (Test-Path $accessibilityPath)) { New-Item -Path $accessibilityPath -Force | Out-Null }
    Set-ItemProperty -Path $accessibilityPath -Name 'CursorSize' -Value $script:PointerSize -Type DWord
    Set-ItemProperty -Path $accessibilityPath -Name 'CursorType' -Value $script:PointerType -Type DWord
    if ($script:PointerType -eq 6) {
        Set-ItemProperty -Path $accessibilityPath -Name 'CursorColor' -Value $script:PointerColor -Type DWord
    }

    if (-not (Test-Path $cursorsPath)) { New-Item -Path $cursorsPath -Force | Out-Null }
    Set-ItemProperty -Path $cursorsPath -Name 'CursorBaseSize' -Value $cursorBaseSize -Type DWord
    Set-ItemProperty -Path $cursorsPath -Name 'Scheme Source' -Value 2 -Type DWord

    if ($script:PointerType -eq 6) {
        if (-not (Test-Path $userCursorDir)) {
            New-Item -Path $userCursorDir -ItemType Directory -Force | Out-Null
        }

        $seeded = $false
        if ($CursorsZip -and (Test-Path $CursorsZip)) {
            Expand-Archive -Path $CursorsZip -DestinationPath $userCursorDir -Force
            $seeded = $true
        }

        if (-not $seeded) {
            foreach ($seedDir in @($persistCursors, (Join-Path $PSScriptRoot 'Cursors'))) {
                if (-not (Test-Path $seedDir)) { continue }
                Get-ChildItem -Path $seedDir -Filter '*_eoa.cur' -ErrorAction SilentlyContinue |
                    Copy-Item -Destination $userCursorDir -Force
                if (@(Get-ChildItem -Path $seedDir -Filter '*_eoa.cur' -ErrorAction SilentlyContinue).Count -gt 0) {
                    $seeded = $true
                    break
                }
            }
        }

        if (-not $seeded) {
            Write-Warning 'Custom pointer: add Cursors.zip beside this script, or pick your color once in Settings > Accessibility > Mouse pointer.'
            return
        }

        Set-ItemProperty -Path $cursorsPath -Name '(Default)' -Value 'Windows custom' -Type String
        $cursorDir = '%LocalAppData%\Microsoft\Windows\Cursors\'
        foreach ($entry in @{
            Arrow       = 'arrow_eoa.cur'
            Help        = 'helpsel_eoa.cur'
            AppStarting = 'busy_eoa.cur'
            Wait        = 'wait_eoa.cur'
            Crosshair   = 'cross_eoa.cur'
            IBeam       = 'ibeam_eoa.cur'
            NWPen       = 'pen_eoa.cur'
            No          = 'unavail_eoa.cur'
            SizeNS      = 'ns_eoa.cur'
            SizeWE      = 'ew_eoa.cur'
            SizeNWSE    = 'nwse_eoa.cur'
            SizeNESW    = 'nesw_eoa.cur'
            SizeAll     = 'move_eoa.cur'
            UpArrow     = 'up_eoa.cur'
            Hand        = 'link_eoa.cur'
            Person      = 'person_eoa.cur'
            Pin         = 'pin_eoa.cur'
        }.GetEnumerator()) {
            Set-ItemProperty -Path $cursorsPath -Name $entry.Key -Value ($cursorDir + $entry.Value) -Type ExpandString
        }
    } else {
        $schemeName = switch ($script:PointerType) { 2 { 'Windows Black' } 3 { 'Windows Inverted' } default { 'Windows Default' } }
        $suffix = switch ($script:PointerType) { 2 { 'r' } 3 { 'i' } default { 'l' } }
        $sysDir = '%SystemRoot%\cursors\'
        Set-ItemProperty -Path $cursorsPath -Name '(Default)' -Value $schemeName -Type String
        foreach ($entry in @{
            Arrow       = "arrow_$suffix.cur"
            Help        = "help_$suffix.cur"
            AppStarting = "wait_$suffix.cur"
            Wait        = "wait_$suffix.cur"
            Crosshair   = "cross_$suffix.cur"
            IBeam       = "beam_$suffix.cur"
            NWPen       = "pen_$suffix.cur"
            No          = "no_$suffix.cur"
            SizeNS      = "size1_$suffix.cur"
            SizeWE      = "size2_$suffix.cur"
            SizeNWSE    = "size3_$suffix.cur"
            SizeNESW    = "size4_$suffix.cur"
            SizeAll     = "move_$suffix.cur"
            UpArrow     = "up_$suffix.cur"
            Hand        = "hand_$suffix.cur"
        }.GetEnumerator()) {
            Set-ItemProperty -Path $cursorsPath -Name $entry.Key -Value ($sysDir + $entry.Value) -Type ExpandString
        }
    }

    $cursorFlags = [WinSetupInput]::SPIF_UPDATEINIFILE -bor [WinSetupInput]::SPIF_SENDCHANGE
    [void][WinSetupInput]::SystemParametersInfo([WinSetupInput]::SPI_SETCURSORSIZE, 0, [uint32]$cursorBaseSize, [WinSetupInput]::SPIF_UPDATEINIFILE)
    [void][WinSetupInput]::SystemParametersInfo([WinSetupInput]::SPI_SETCURSORS, 0, 0, $cursorFlags)
}

function Install-WinSetupMousePointerPersistence {
    param(
        [string]$SourceDir = $PSScriptRoot
    )

    $persistDir = Join-Path $env:LOCALAPPDATA 'WinSetup'
    $persistCursors = Join-Path $persistDir 'Cursors'
    $persistZip = Join-Path $persistDir 'Cursors.zip'
    $persistScript = Join-Path $persistDir 'Set-MousePointer.ps1'
    $logonScript = Join-Path $persistDir 'Apply-MousePointerAtLogon.ps1'
    $taskName = 'WinSetup-MousePointer'

    if (-not (Test-Path $persistDir)) { New-Item -Path $persistDir -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $persistCursors)) { New-Item -Path $persistCursors -ItemType Directory -Force | Out-Null }

    foreach ($pair in @(
        @{ Src = (Join-Path $SourceDir 'Set-MousePointer.ps1'); Dst = $persistScript }
        @{ Src = (Join-Path $SourceDir 'Apply-MousePointerAtLogon.ps1'); Dst = $logonScript }
        @{ Src = (Join-Path $SourceDir 'Cursors.zip'); Dst = $persistZip }
    )) {
        if (Test-Path $pair.Src) {
            Copy-Item -Path $pair.Src -Destination $pair.Dst -Force
        }
    }

    if (Test-Path $persistZip) {
        Expand-Archive -Path $persistZip -DestinationPath $persistCursors -Force
    }

    $userCursorDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
    if (Test-Path $persistCursors) {
        Get-ChildItem -Path $persistCursors -Filter '*_eoa.cur' -ErrorAction SilentlyContinue |
            Copy-Item -Destination $userCursorDir -Force
    }

    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' `
        -Name 'WinSetup-MousePointer' -ErrorAction SilentlyContinue

    if (-not (Test-Path $logonScript)) { return }

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logonScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null
}

if ($MyInvocation.InvocationName -ne '.') {
    Set-WinSetupMousePointer
}
