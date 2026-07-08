# WinSetup: reapply turquoise mouse pointer (logon task + called from Configure.ps1)
$accessibilityPath = 'HKCU:\Software\Microsoft\Accessibility'
$cursorsPath = 'HKCU:\Control Panel\Cursors'
$cursorDir = '%LocalAppData%\Microsoft\Windows\Cursors\'
$cursorColorTurquoise = 16760576 # COLORREF 0x00FFBF00
$userCursorDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$cursorStore = Join-Path $env:LOCALAPPDATA 'WinSetup\Cursors'

if (Test-Path $cursorStore) {
    if (-not (Test-Path $userCursorDir)) {
        New-Item -Path $userCursorDir -ItemType Directory -Force | Out-Null
    }
    Get-ChildItem -Path $cursorStore -Filter '*.cur' -ErrorAction SilentlyContinue |
        Copy-Item -Destination $userCursorDir -Force
}

if (-not (Test-Path $accessibilityPath)) {
    New-Item -Path $accessibilityPath -Force | Out-Null
}
Set-ItemProperty -Path $accessibilityPath -Name 'CursorColor' -Value $cursorColorTurquoise -Type DWord
Set-ItemProperty -Path $accessibilityPath -Name 'CursorSize' -Value 3 -Type DWord
Set-ItemProperty -Path $accessibilityPath -Name 'CursorType' -Value 6 -Type DWord

$themesPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes'
Set-ItemProperty -Path $themesPath -Name 'ThemeChangesMousePointers' -Value 0 -Type DWord -ErrorAction SilentlyContinue

if (-not ('CursorSpi' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class CursorSpi {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
    public const uint SPI_SETCURSORS = 0x0057;
    public const uint SPI_SETCURSORSIZE = 0x2029;
    public const uint SPIF_UPDATEINIFILE = 0x01;
    public const uint SPIF_SENDCHANGE = 0x02;
}
'@
}

$cursorRefreshFlags = [CursorSpi]::SPIF_UPDATEINIFILE -bor [CursorSpi]::SPIF_SENDCHANGE

if (-not (Test-Path $cursorsPath)) { New-Item -Path $cursorsPath -Force | Out-Null }
Set-ItemProperty -Path $cursorsPath -Name '(Default)' -Value 'Windows custom' -Type String
Set-ItemProperty -Path $cursorsPath -Name 'CursorBaseSize' -Value 64 -Type DWord
Set-ItemProperty -Path $cursorsPath -Name 'Scheme Source' -Value 2 -Type DWord

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

[CursorSpi]::SystemParametersInfo([CursorSpi]::SPI_SETCURSORSIZE, 0, 64, [CursorSpi]::SPIF_UPDATEINIFILE) | Out-Null
[CursorSpi]::SystemParametersInfo([CursorSpi]::SPI_SETCURSORS, 0, 0, $cursorRefreshFlags) | Out-Null
