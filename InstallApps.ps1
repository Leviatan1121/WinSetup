#region STA bootstrap (WPF requires STA)
if ($PSCommandPath -and ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')) {
    $staArgs = @(
        '-NoProfile'
        '-Sta'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $PSCommandPath
    )
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $staArgs -Wait -PassThru
    exit $process.ExitCode
}
#endregion

#region Category catalog
$CategoryCatalog = [ordered]@{
    Communication = @{
        Label    = 'Communication'
        Packages = @(
            @{ Id = 'Discord.Discord'; Name = 'Discord' }
            @{ Id = '9NKSQGP7F2NH'; Name = 'WhatsApp'; Source = 'msstore' }
            @{ Id = 'OpenWhisperSystems.Signal'; Name = 'Signal' }
            @{ Id = 'Telegram.TelegramDesktop'; Name = 'Telegram' }
        )
    }
    Browsers = @{
        Label    = 'Browsers'
        Packages = @(
            @{ Id = 'Microsoft.Edge'; Name = 'Microsoft Edge' }
            @{ Id = 'Google.Chrome'; Name = 'Google Chrome' }
            @{ Id = 'Mozilla.Firefox'; Name = 'Mozilla Firefox' }
            @{ Id = 'Vivaldi.Vivaldi'; Name = 'Vivaldi' }
            @{ Id = 'Opera.Opera'; Name = 'Opera' }
            @{ Id = 'Opera.OperaAir'; Name = 'Opera Air' }
            @{ Id = 'Opera.OperaGX'; Name = 'Opera GX' }
        )
    }
    Gaming = @{
        Label    = 'Gaming'
        Packages = @(
            @{ Id = 'Valve.Steam'; Name = 'Steam' }
            @{ Id = 'EpicGames.EpicGamesLauncher'; Name = 'Epic Games Launcher' }
        )
    }
    Streaming = @{
        Label    = 'Streaming'
        Packages = @(
            @{ Id = 'OBSProject.OBSStudio'; Name = 'OBS Studio' }
            @{ Id = 'Elgato.StreamDeck'; Name = 'Elgato Stream Deck' }
            @{ Id = 'Elgato.WaveLink'; Name = 'Elgato Wave Link' }
            @{
                Name          = 'Pretzel'
                Id            = 'Pretzel.Desktop'
                InstallerUrl  = 'https://download.pretzel.rocks/PretzelDesktop.exe'
                InstallerArgs = @('/S')
            }
        )
    }
    Design = @{
        Label    = 'Design'
        Packages = @(
            @{ Id = 'BlenderFoundation.Blender'; Name = 'Blender' }
            @{ Id = 'Figma.Figma'; Name = 'Figma' }
            @{ Id = 'Canva.Canva'; Name = 'Canva' }
        )
    }
    AI = @{
        Label    = 'AI'
        Packages = @(
            @{ Id = 'ElementLabs.LMStudio'; Name = 'LM Studio' }
            @{ Id = 'Ollama.Ollama'; Name = 'Ollama' }
        )
    }
    Utilities = @{
        Label    = 'Utilities'
        Packages = @(
            @{ Id = '7zip.7zip'; Name = '7-Zip' }
            @{ Id = 'Microsoft.PowerToys'; Name = 'PowerToys' }
            @{ Id = 'VideoLAN.VLC'; Name = 'VLC' }
            @{ Id = 'Spotify.Spotify'; Name = 'Spotify' }
            @{ Id = 'ALCPU.CoreTemp'; Name = 'Core Temp' }
            @{ Id = 'KDE.Filelight'; Name = 'Filelight' }
            @{ Id = 'voidtools.Everything'; Name = 'Everything' }
            @{ Id = 'voidtools.Everything.Cli'; Name = 'Everything CLI' }
            @{ Id = 'voidtools.Everything.Lite'; Name = 'Everything Lite' }
            @{ Id = '9P8LTPGCBZXD'; Name = 'Wintoys'; Source = 'msstore' }
        )
    }
    Graphics = @{
        Label    = 'Graphics'
        Packages = @(
            @{ Id = 'XP8CLZL93F5Z4P'; Name = 'NVIDIA App'; Source = 'msstore' }
            @{ Id = 'Nvidia.PhysX'; Name = 'NVIDIA PhysX' }
            @{ Id = 'Nvidia.RTXVoice'; Name = 'NVIDIA RTX Voice' }
            @{ Id = '9P8K5G2MWW6Z'; Name = 'Intel Graphics Software'; Source = 'msstore' }
        )
    }
    Development = @{
        Label    = 'Development'
        Packages = @(
            @{ Id = 'Git.Git'; Name = 'Git' }
            @{ Id = 'GitHub.GitLFS'; Name = 'Git LFS' }
            @{ Id = 'GitHub.GitHubDesktop'; Name = 'GitHub Desktop' }
            @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' }
            @{
                Name              = 'Cursor'
                Id                = 'Anysphere.Cursor'
                InstallerUrl      = 'https://api2.cursor.sh/updates/download/golden/win32-x64-user/cursor/'
                InstallerFileName = 'CursorSetup.exe'
                InstallerArgs     = @(
                    '/CURRENTUSER'
                    '/VERYSILENT'
                    '/SUPPRESSMSGBOXES'
                    '/NORESTART'
                    '/SP-'
                    '/MERGETASKS=!runcode'
                )
            }
            @{ Id = 'jdx.mise'; Name = 'mise' }
            @{ Name = 'Node.js (mise)'; MiseTool = 'node@lts' }
            @{ Name = 'Python (mise)'; MiseTool = 'python@latest' }
            @{ Name = 'Go (mise)'; MiseTool = 'go@latest' }
            @{ Id = 'Rustlang.Rustup'; Name = 'Rust' }
            @{ Id = 'GodotEngine.GodotEngine'; Name = 'Godot' }
            @{
                Name          = 'C++ Build Tools'
                Id            = 'Microsoft.VisualStudio.BuildTools'
                InstallerUrl  = 'https://aka.ms/vs/stable/vs_BuildTools.exe'
                InstallerArgs = @(
                    '--quiet'
                    '--wait'
                    '--norestart'
                    '--add'
                    'Microsoft.VisualStudio.Workload.VCTools'
                    '--includeRecommended'
                )
            }
        )
    }
}
#endregion

#region Helpers — winget (self-contained; no external WinSetup scripts)
function Invoke-InstallAppsWingetCommand {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$WingetArgs
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return 0
    }

    $exitCode = 0
    $null = & winget @WingetArgs 2>&1
    if ($null -ne $LASTEXITCODE) {
        $exitCode = $LASTEXITCODE
    }
    return $exitCode
}

function Resolve-InstallAppsWingetExitCode {
    param([Parameter(Mandatory = $true)][int]$ExitCode)

    $bytes = [BitConverter]::GetBytes([int32]$ExitCode)
    $asUInt = [BitConverter]::ToUInt32($bytes, 0)
    $normalized = [BitConverter]::ToInt32($bytes, 0)
    $hex = '0x{0:X8}' -f $asUInt

    $names = @{
        0                      = 'SUCCESS'
        [int32]0x8A15002B      = 'UPDATE_NOT_APPLICABLE'
        [int32]0x8A15004F      = 'UPGRADE_VERSION_NOT_NEWER'
        [int32]0x8A150014      = 'NO_APPLICATIONS_FOUND'
    }

    $name = $names[$normalized]
    if (-not $name) {
        $name = "UNKNOWN ($normalized / $hex)"
    }

    $benign = $normalized -in @(0, [int32]0x8A15002B, [int32]0x8A15004F)

    return [PSCustomObject]@{
        ExitCode  = $normalized
        Hex       = $hex
        Name      = $name
        IsBenign  = $benign
        IsSuccess = ($normalized -eq 0)
    }
}

function Update-InstallAppsWingetPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
    Get-Command winget -ErrorAction SilentlyContinue | Out-Null
}

function Test-InstallAppsAppInstallerReady {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $false
    }

    $exitCode = Invoke-InstallAppsWingetCommand upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements --disable-interactivity
    $resolved = Resolve-InstallAppsWingetExitCode -ExitCode $exitCode
    return ($resolved.IsSuccess -or $resolved.IsBenign)
}

function Repair-InstallAppsWingetAppInstallerElevated {
    Write-Host '[!] Approve UAC to repair App Installer (winget)...' -ForegroundColor Yellow

    $elevatedCommand = @'
$ErrorActionPreference = 'Continue'
function Invoke-InstallAppsWingetCommand {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$WingetArgs)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return 0 }
    $exitCode = 0
    $null = & winget @WingetArgs 2>&1
    if ($null -ne $LASTEXITCODE) { $exitCode = $LASTEXITCODE }
    return $exitCode
}
function Resolve-InstallAppsWingetExitCode {
    param([int]$ExitCode)
    $bytes = [BitConverter]::GetBytes([int32]$ExitCode)
    $normalized = [BitConverter]::ToInt32($bytes, 0)
    $benign = $normalized -in @(0, [int32]0x8A15002B, [int32]0x8A15004F)
    return [PSCustomObject]@{ IsSuccess = ($normalized -eq 0); IsBenign = $benign }
}
$pinEnableExit = Invoke-InstallAppsWingetCommand settings --enable BypassCertificatePinningForMicrosoftStore
$upgradeExit = Invoke-InstallAppsWingetCommand upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements --disable-interactivity
$null = Invoke-InstallAppsWingetCommand settings --disable BypassCertificatePinningForMicrosoftStore
$resolved = Resolve-InstallAppsWingetExitCode -ExitCode $upgradeExit
if ($resolved.IsSuccess -or $resolved.IsBenign) { exit 0 }
exit 1
'@

    try {
        $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $elevatedCommand
        )
        return ($process.ExitCode -eq 0)
    } catch {
        Write-Warning "Elevated winget repair failed: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-InstallAppsWingetAppInstaller {
    Write-Host '[*] Checking App Installer (winget)...' -ForegroundColor DarkGray

    if (Test-InstallAppsAppInstallerReady) {
        Update-InstallAppsWingetPath
        Write-Host '[+] App Installer is ready.' -ForegroundColor Green
        return $true
    }

    Write-Host '[~] App Installer needs repair — elevating...' -ForegroundColor Yellow

    if (-not (Repair-InstallAppsWingetAppInstallerElevated)) {
        Write-Host '[!] Could not repair App Installer. Install it from the Microsoft Store and run again.' -ForegroundColor Red
        return $false
    }

    if (Test-InstallAppsAppInstallerReady) {
        Update-InstallAppsWingetPath
        Write-Host '[+] App Installer repaired.' -ForegroundColor Green
        return $true
    }

    Write-Host '[!] App Installer still failing after repair.' -ForegroundColor Red
    return $false
}

function Get-SortedInstallCatalogEntries {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Catalog
    )

    $entries = foreach ($categoryKey in $Catalog.Keys) {
        $category = $Catalog[$categoryKey]
        foreach ($package in $category.Packages) {
            [pscustomobject]@{
                CategoryKey   = $categoryKey
                CategoryLabel = $category.Label
                Package       = $package
            }
        }
    }

    return @($entries | Sort-Object { $_.Package.Name })
}

function Get-PackageSubtitle {
    param($Package)

    if ($Package.InstallerUrl) {
        return 'Direct download'
    }

    if ($Package.MiseTool) {
        return "mise $($Package.MiseTool)"
    }

    return [string]$Package.Id
}

function ConvertTo-InstallPackageArray {
    param(
        [AllowNull()]
        $Selection
    )

    if ($null -eq $Selection) {
        return @()
    }

    # PowerShell unwraps single-element arrays from functions; a lone package arrives as one hashtable.
    # @($hashtable) enumerates keys (Count = 2+), not the package — detect and re-wrap.
    if ($Selection -is [hashtable] -and $Selection.ContainsKey('Name')) {
        return ,@($Selection)
    }

    return @($Selection)
}

function Test-WingetAvailable {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '[!] winget is not available on this system.' -ForegroundColor Red
        Write-Host '    Install App Installer from the Microsoft Store, then run this script again.' -ForegroundColor DarkYellow
        return $false
    }
    return $true
}

function Show-InstallSelectionWindow {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Catalog
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinSetup"
        Height="640"
        Width="920"
        MinHeight="520"
        MinWidth="760"
        WindowStartupLocation="CenterScreen"
        Background="#232629"
        FontFamily="Segoe UI"
        FontSize="12"
        TextOptions.TextFormattingMode="Display"
        UseLayoutRounding="True">
    <Window.Resources>
        <SolidColorBrush x:Key="Brush.Background" Color="#232629"/>
        <SolidColorBrush x:Key="Brush.Foreground" Color="#F7F7F7"/>
        <SolidColorBrush x:Key="Brush.Accent" Color="#2E77FF"/>
        <SolidColorBrush x:Key="Brush.Category" Color="#5BDCFF"/>
        <SolidColorBrush x:Key="Brush.Border" Color="#2F373D"/>
        <SolidColorBrush x:Key="Brush.Card" Color="#2A2D31"/>
        <SolidColorBrush x:Key="Brush.CardHover" Color="#3C3C3C"/>
        <SolidColorBrush x:Key="Brush.CardSelected" Color="#4C4C4C"/>
        <SolidColorBrush x:Key="Brush.Input" Color="#1A1C1F"/>
        <SolidColorBrush x:Key="Brush.Muted" Color="#9AA0A6"/>

        <Style x:Key="FilterButtonStyle" TargetType="ToggleButton">
            <Setter Property="Foreground" Value="{StaticResource Brush.Foreground}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="{StaticResource Brush.Border}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,6"/>
            <Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border x:Name="Root"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Root" Property="Background" Value="{StaticResource Brush.Accent}"/>
                                <Setter TargetName="Root" Property="BorderBrush" Value="{StaticResource Brush.Accent}"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Root" Property="Background" Value="#3B4252"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsChecked" Value="True"/>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="Root" Property="Background" Value="#3D84FF"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Foreground" Value="{StaticResource Brush.Foreground}"/>
            <Setter Property="Background" Value="#1E3747"/>
            <Setter Property="BorderBrush" Value="{StaticResource Brush.Border}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="MinWidth" Value="88"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Root"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Root" Property="Background" Value="#3B4252"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Root" Property="Background" Value="#5E81AC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="{StaticResource Brush.Accent}"/>
            <Setter Property="BorderBrush" Value="{StaticResource Brush.Accent}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3D84FF"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#1F5FD6"/>
                </Trigger>
            </Style.Triggers>
        </Style>

    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,16">
            <TextBlock Text="WinSetup"
                       Foreground="{StaticResource Brush.Foreground}"
                       FontSize="24"
                       FontWeight="SemiBold"/>
            <TextBlock Text="Select apps to install."
                       Foreground="{StaticResource Brush.Muted}"
                       Margin="0,4,0,0"/>
        </StackPanel>

        <WrapPanel x:Name="CategoryFilters" Grid.Row="1" Margin="0,0,0,12"/>

        <Grid Grid.Row="2" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0"
                    Background="{StaticResource Brush.Input}"
                    BorderBrush="{StaticResource Brush.Border}"
                    BorderThickness="1"
                    CornerRadius="4"
                    Padding="10,0"
                    Margin="0,0,8,0">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0"
                               Text="&#xE721;"
                               FontFamily="Segoe MDL2 Assets"
                               Foreground="{StaticResource Brush.Muted}"
                               VerticalAlignment="Center"
                               Margin="0,0,8,0"/>
                    <TextBox x:Name="SearchBox"
                             Grid.Column="1"
                             Background="Transparent"
                             BorderThickness="0"
                             Foreground="{StaticResource Brush.Foreground}"
                             CaretBrush="{StaticResource Brush.Foreground}"
                             VerticalContentAlignment="Center"
                             Height="32"/>
                </Grid>
            </Border>

            <Button x:Name="SelectAllButton"
                    Grid.Column="1"
                    Content="All"
                    Style="{StaticResource ActionButtonStyle}"
                    Margin="0,0,8,0"/>
            <Button x:Name="SelectNoneButton"
                    Grid.Column="2"
                    Content="None"
                    Style="{StaticResource ActionButtonStyle}"/>
        </Grid>

        <Border Grid.Row="3"
                Background="#1A1C1F"
                BorderBrush="{StaticResource Brush.Border}"
                BorderThickness="1"
                CornerRadius="6"
                Padding="12"
                ClipToBounds="True">
            <ScrollViewer x:Name="AppScrollViewer"
                          VerticalScrollBarVisibility="Hidden"
                          HorizontalScrollBarVisibility="Disabled"
                          PanningMode="VerticalOnly">
                <WrapPanel x:Name="AppPanel">
                    <WrapPanel.Width>
                        <Binding Path="ViewportWidth" RelativeSource="{RelativeSource AncestorType=ScrollViewer}"/>
                    </WrapPanel.Width>
                </WrapPanel>
            </ScrollViewer>
        </Border>

        <Grid Grid.Row="4" Margin="0,16,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <TextBlock x:Name="SelectionSummary"
                       Grid.Column="0"
                       VerticalAlignment="Center"
                       Foreground="{StaticResource Brush.Muted}"/>

            <Button x:Name="CancelButton"
                    Grid.Column="1"
                    Content="Cancel"
                    Style="{StaticResource ActionButtonStyle}"
                    Margin="0,0,8,0"/>
            <Button x:Name="InstallButton"
                    Grid.Column="2"
                    Content="Install"
                    Style="{StaticResource PrimaryButtonStyle}"/>
        </Grid>
    </Grid>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $categoryFilters = $window.FindName('CategoryFilters')
    $searchBox = $window.FindName('SearchBox')
    $appPanel = $window.FindName('AppPanel')
    $selectionSummary = $window.FindName('SelectionSummary')
    $selectAllButton = $window.FindName('SelectAllButton')
    $selectNoneButton = $window.FindName('SelectNoneButton')
    $cancelButton = $window.FindName('CancelButton')
    $installButton = $window.FindName('InstallButton')

    $script:InstallDialogResult = $null
    $script:SelectedPackages = @()

    $script:InstallUi = @{
        AppPanel         = $appPanel
        AppTiles         = New-Object System.Collections.Generic.List[object]
        ActiveCategory   = 'All'
        SearchBox        = $searchBox
        SelectionSummary = $selectionSummary
        CategoryFilters  = $categoryFilters
        CardCornerRadius = 6
        Brushes          = @{
            Foreground   = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F7F7F7')
            Category     = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#5BDCFF')
            Muted        = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#9AA0A6')
            Card         = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2A2D31')
            CardHover    = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#3C3C3C')
            CardSelected = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#4C4C4C')
            Accent       = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2E77FF')
            Border       = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2F373D')
        }
    }

    $script:InstallUi.UpdateTileClip = {
        param($Border)

        $radius = $script:InstallUi.CardCornerRadius
        $width = [Math]::Max($Border.ActualWidth, 1)
        $height = [Math]::Max($Border.ActualHeight, 1)
        $Border.Clip = [System.Windows.Media.RectangleGeometry]::new(
            [System.Windows.Rect]::new(0, 0, $width, $height),
            $radius,
            $radius
        )
    }

    $script:InstallUi.UpdateTileVisual = {
        param($Tile)

        $brushes = $script:InstallUi.Brushes
        if ($Tile.IsSelected) {
            $Tile.Border.Background = $brushes.CardSelected
            $Tile.Border.BorderBrush = $brushes.Accent
        } else {
            $Tile.Border.Background = $brushes.Card
            $Tile.Border.BorderBrush = $brushes.Border
        }

        $Tile.Border.BorderThickness = [System.Windows.Thickness]::new(1)
        $script:InstallUi.UpdateTileClip.Invoke($Tile.Border)
    }

    $script:InstallUi.UpdateSelectionSummary = {
        $totalCount = $script:InstallUi.AppTiles.Count
        $visibleCount = $script:InstallUi.GetVisibleTiles.Invoke().Count
        $selectedCount = @($script:InstallUi.AppTiles | Where-Object { $_.IsSelected }).Count

        $query = $script:InstallUi.SearchBox.Text.Trim()
        $hasSearch = -not [string]::IsNullOrWhiteSpace($query)
        $hasCategoryFilter = $script:InstallUi.ActiveCategory -ne 'All'
        $isFiltered = $hasSearch -or $hasCategoryFilter

        if ($isFiltered) {
            $appsPart = if ($visibleCount -eq 1) {
                "Showing 1 of $totalCount app"
            } else {
                "Showing $visibleCount of $totalCount apps"
            }
        } elseif ($totalCount -eq 1) {
            $appsPart = '1 app'
        } else {
            $appsPart = "$totalCount apps"
        }

        $filterParts = @()
        if ($hasCategoryFilter) {
            $categoryLabel = $script:InstallUi.ActiveCategory
            foreach ($child in $script:InstallUi.CategoryFilters.Children) {
                if ([string]$child.Tag -eq $script:InstallUi.ActiveCategory) {
                    $categoryLabel = [string]$child.Content
                    break
                }
            }
            $filterParts += $categoryLabel
        }

        if ($hasSearch) {
            $filterParts += "search: `"$query`""
        }

        $selectedPart = if ($selectedCount -eq 1) {
            '1 selected'
        } else {
            "$selectedCount selected"
        }

        if ($filterParts.Count -gt 0) {
            $script:InstallUi.SelectionSummary.Text = "$selectedPart | $appsPart ($($filterParts -join ' | '))"
        } else {
            $script:InstallUi.SelectionSummary.Text = "$selectedPart | $appsPart"
        }
    }

    $script:InstallUi.TestTileVisible = {
        param($Tile)

        $query = $script:InstallUi.SearchBox.Text.Trim().ToLowerInvariant()
        $matchesSearch = [string]::IsNullOrWhiteSpace($query) `
            -or $Tile.Package.Name.ToLowerInvariant().Contains($query)

        $matchesCategory = ($script:InstallUi.ActiveCategory -eq 'All') `
            -or ($Tile.CategoryKey -eq $script:InstallUi.ActiveCategory)

        return $matchesSearch -and $matchesCategory
    }

    $script:InstallUi.GetVisibleTiles = {
        return @(
            $script:InstallUi.AppTiles |
                Where-Object { $script:InstallUi.TestTileVisible.Invoke($_) } |
                Sort-Object { $_.Package.Name }
        )
    }

    $script:InstallUi.UpdateTileVisibility = {
        $panel = $script:InstallUi.AppPanel
        $panel.Children.Clear()

        foreach ($tile in $script:InstallUi.GetVisibleTiles.Invoke()) {
            $panel.Children.Add($tile.Border) | Out-Null
        }

        $panel.InvalidateMeasure()
        $panel.InvalidateArrange()
        $script:InstallUi.UpdateSelectionSummary.Invoke()
    }

    $script:InstallUi.SetTileSelected = {
        param(
            $Tile,
            [bool]$Selected
        )

        $Tile.IsSelected = $Selected
        $script:InstallUi.UpdateTileVisual.Invoke($Tile)
        $script:InstallUi.UpdateSelectionSummary.Invoke()
    }

    foreach ($categoryKey in $Catalog.Keys) {
        $category = $Catalog[$categoryKey]
        $brushes = $script:InstallUi.Brushes

        $filterButton = New-Object System.Windows.Controls.Primitives.ToggleButton
        $filterButton.Content = $category.Label
        $filterButton.Tag = $categoryKey
        $filterButton.Style = $window.Resources['FilterButtonStyle']

        $filterButton.Add_Checked({
            param($sender, $e)

            foreach ($child in $script:InstallUi.CategoryFilters.Children) {
                if ($child -ne $sender) {
                    $child.IsChecked = $false
                }
            }

            $script:InstallUi.ActiveCategory = [string]$sender.Tag
            $script:InstallUi.UpdateTileVisibility.Invoke()
        })

        $filterButton.Add_Unchecked({
            param($sender, $e)

            $anyChecked = $false
            foreach ($child in $script:InstallUi.CategoryFilters.Children) {
                if ($child.IsChecked) {
                    $anyChecked = $true
                    break
                }
            }

            if (-not $anyChecked) {
                $sender.IsChecked = $true
            }
        })

        $categoryFilters.Children.Add($filterButton) | Out-Null
    }

    $allFilterButton = New-Object System.Windows.Controls.Primitives.ToggleButton
    $allFilterButton.Content = 'All'
    $allFilterButton.Tag = 'All'
    $allFilterButton.IsChecked = $true
    $allFilterButton.Style = $window.Resources['FilterButtonStyle']
    $allFilterButton.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)

    $allFilterButton.Add_Checked({
        param($sender, $e)

        foreach ($child in $script:InstallUi.CategoryFilters.Children) {
            if ($child -ne $sender) {
                $child.IsChecked = $false
            }
        }

        $script:InstallUi.ActiveCategory = 'All'
        $script:InstallUi.UpdateTileVisibility.Invoke()
    })

    $allFilterButton.Add_Unchecked({
        param($sender, $e)

        $anyChecked = $false
        foreach ($child in $script:InstallUi.CategoryFilters.Children) {
            if ($child.IsChecked) {
                $anyChecked = $true
                break
            }
        }

        if (-not $anyChecked) {
            $sender.IsChecked = $true
        }
    })

    $categoryFilters.Children.Insert(0, $allFilterButton) | Out-Null

    foreach ($entry in (Get-SortedInstallCatalogEntries -Catalog $Catalog)) {
        $brushes = $script:InstallUi.Brushes

        $border = New-Object System.Windows.Controls.Border
        $border.Width = 200
        $border.Height = 72
        $border.Margin = [System.Windows.Thickness]::new(4)
        $border.CornerRadius = [System.Windows.CornerRadius]::new($script:InstallUi.CardCornerRadius)
        $border.Cursor = [System.Windows.Input.Cursors]::Hand
        $border.Background = $brushes.Card
        $border.BorderBrush = $brushes.Border
        $border.BorderThickness = [System.Windows.Thickness]::new(1)
        $border.SnapsToDevicePixels = $false
        [System.Windows.Media.RenderOptions]::SetEdgeMode($border, [System.Windows.Media.EdgeMode]::Unspecified)

        $border.Add_SizeChanged({
            param($sender, $e)
            $script:InstallUi.UpdateTileClip.Invoke($sender)
        })

        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Margin = [System.Windows.Thickness]::new(12, 10, 12, 10)

        $categoryText = New-Object System.Windows.Controls.TextBlock
        $categoryText.Text = $entry.CategoryLabel.ToUpperInvariant()
        $categoryText.Foreground = $brushes.Category
        $categoryText.FontSize = 10
        $categoryText.FontWeight = [System.Windows.FontWeights]::SemiBold

        $nameText = New-Object System.Windows.Controls.TextBlock
        $nameText.Text = $entry.Package.Name
        $nameText.Foreground = $brushes.Foreground
        $nameText.FontSize = 13
        $nameText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $nameText.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
        $nameText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $idText = New-Object System.Windows.Controls.TextBlock
        $idText.Text = Get-PackageSubtitle -Package $entry.Package
        $idText.Foreground = $brushes.Muted
        $idText.FontSize = 10
        $idText.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
        $idText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $stack.Children.Add($categoryText) | Out-Null
        $stack.Children.Add($nameText) | Out-Null
        $stack.Children.Add($idText) | Out-Null
        $border.Child = $stack

        $tile = [pscustomobject]@{
            CategoryKey   = $entry.CategoryKey
            CategoryLabel = $entry.CategoryLabel
            Package       = $entry.Package
            Border        = $border
            IsSelected    = $false
        }

        $border.Tag = $tile

        $border.Add_MouseLeftButtonUp({
            param($sender, $e)

            $tileRef = $sender.Tag
            $script:InstallUi.SetTileSelected.Invoke($tileRef, (-not $tileRef.IsSelected))
        })

        $border.Add_MouseEnter({
            param($sender, $e)

            $tileRef = $sender.Tag
            if (-not $tileRef.IsSelected) {
                $sender.Background = $script:InstallUi.Brushes.CardHover
            }
        })

        $border.Add_MouseLeave({
            param($sender, $e)

            $script:InstallUi.UpdateTileVisual.Invoke($sender.Tag)
        })

        $script:InstallUi.AppTiles.Add($tile) | Out-Null
    }

    $script:InstallUi.UpdateTileVisibility.Invoke()

    $searchBox.Add_TextChanged({
        param($sender, $e)
        $script:InstallUi.UpdateTileVisibility.Invoke()
    })

    $selectAllButton.Add_Click({
        param($sender, $e)

        foreach ($tile in $script:InstallUi.GetVisibleTiles.Invoke()) {
            $script:InstallUi.SetTileSelected.Invoke($tile, $true)
        }
    })

    $selectNoneButton.Add_Click({
        param($sender, $e)

        foreach ($tile in $script:InstallUi.GetVisibleTiles.Invoke()) {
            $script:InstallUi.SetTileSelected.Invoke($tile, $false)
        }
    })

    $cancelButton.Add_Click({
        $script:InstallDialogResult = 'Cancel'
        $window.Close()
    })

    $installButton.Add_Click({
        $script:SelectedPackages = @(
            $script:InstallUi.AppTiles |
                Where-Object { $_.IsSelected } |
                Sort-Object { $_.Package.Name } |
                ForEach-Object { $_.Package }
        )
        $script:InstallDialogResult = 'Install'
        $window.Close()
    })

    $window.Add_Closing({
        if (-not $script:InstallDialogResult) {
            $script:InstallDialogResult = 'Cancel'
        }
    })

    [void]$window.ShowDialog()
    $window = $null
    $script:InstallUi = $null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    if ($script:InstallDialogResult -ne 'Install') {
        return ,@()
    }

    return ,@(
        $script:InstallUi.AppTiles |
            Where-Object { $_.IsSelected } |
            Sort-Object { $_.Package.Name } |
            ForEach-Object { $_.Package }
    )
}

function Install-DownloadedPackage {
    param(
        $Package
    )

    $url = [string]$Package.InstallerUrl
    $name = [string]$Package.Name
    $fileName = if ($Package.InstallerFileName) {
        [string]$Package.InstallerFileName
    } else {
        [IO.Path]::GetFileName(([Uri]$url).LocalPath)
    }

    if ([string]::IsNullOrWhiteSpace($fileName) -or -not $fileName.Contains('.')) {
        $fileName = 'installer.exe'
    }

    $tempDir = Join-Path $env:TEMP 'WinSetup-Install'
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $installerPath = Join-Path $tempDir $fileName

    Write-Host "[*] Downloading $name..." -ForegroundColor DarkGray

    try {
        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-Host "[!] Download failed for $name. $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    $installerArgs = if ($Package.InstallerArgs) {
        @($Package.InstallerArgs)
    } else {
        @('/S')
    }

    Write-Host "[*] Installing $name..." -ForegroundColor DarkGray

    $process = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru

    # 3010 = success, reboot required (common for Visual Studio installers).
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Host "[!] Installer failed for $name. Exit code: $($process.ExitCode)" -ForegroundColor Red
        return $false
    }

    if ($process.ExitCode -eq 3010) {
        Write-Host '[~] Install finished. A reboot may be required to complete setup.' -ForegroundColor Yellow
    }

    Write-Host "[+] $name installed." -ForegroundColor Green
    return $true
}

function Update-SessionUserPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    if ($machinePath -and $userPath) {
        $env:Path = "$machinePath;$userPath"
    } elseif ($machinePath) {
        $env:Path = $machinePath
    } elseif ($userPath) {
        $env:Path = $userPath
    }
}

function Get-MiseExecutable {
    Update-SessionUserPath

    $paths = @(
        (Join-Path $env:USERPROFILE '.local\bin\mise.exe')
    )

    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetPackages) {
        $paths += Get-ChildItem -Path $wingetPackages -Directory -Filter 'jdx.mise*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'mise\bin\mise.exe' }
    }

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    $command = Get-Command mise -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    return $null
}

function Add-UserPathEntry {
    param(
        [string]$PathToAdd
    )

    if ([string]::IsNullOrWhiteSpace($PathToAdd)) {
        return $false
    }

    $normalized = $PathToAdd.TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $segments = @()
    if ($userPath) {
        $segments = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() })
    }

    foreach ($segment in $segments) {
        if ($segment.TrimEnd('\') -ieq $normalized) {
            return $false
        }
    }

    $segments += $normalized
    [Environment]::SetEnvironmentVariable('Path', ($segments -join ';'), 'User')
    return $true
}

function Initialize-MiseEnvironment {
    $miseExe = Get-MiseExecutable
    if (-not $miseExe) {
        return $false
    }

    $added = $false
    $miseBin = Split-Path -Parent $miseExe
    if (Add-UserPathEntry -PathToAdd $miseBin) {
        $added = $true
    }

    $shimsDir = Join-Path $env:LOCALAPPDATA 'mise\shims'
    if (Add-UserPathEntry -PathToAdd $shimsDir) {
        $added = $true
    }

    $localMiseBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path -LiteralPath (Join-Path $localMiseBin 'mise.exe')) {
        if (Add-UserPathEntry -PathToAdd $localMiseBin) {
            $added = $true
        }
    }

    if ($added) {
        Update-SessionUserPath
        Write-Host '[+] Added mise binary and shims to user PATH.' -ForegroundColor Green
    }

    & $miseExe reshim | Out-Null
    return $true
}

function Ensure-MiseInstalled {
    $miseExe = Get-MiseExecutable
    if ($miseExe) {
        return $miseExe
    }

    Write-Host '[*] Installing mise (required for language runtimes)...' -ForegroundColor DarkGray
    if (-not (Install-WingetPackage -Id 'jdx.mise' -Name 'mise')) {
        return $null
    }

    return Get-MiseExecutable
}

function Install-MiseTool {
    param(
        [string]$Name,
        [string]$Tool
    )

    $miseExe = Ensure-MiseInstalled
    if (-not $miseExe) {
        Write-Host "[!] mise is not available. Could not install $Name." -ForegroundColor Red
        return $false
    }

    Initialize-MiseEnvironment | Out-Null

    Write-Host "[*] Installing $Name with mise ($Tool)..." -ForegroundColor DarkGray
    & $miseExe use --global $Tool
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] mise use --global $Tool failed. Exit code:" $LASTEXITCODE -ForegroundColor Red
        return $false
    }

    Write-Host "[+] $Name installed via mise." -ForegroundColor Green
    Initialize-MiseEnvironment | Out-Null
    return $true
}

function Wait-InstallAppsDismiss {
    Read-Host 'Press Enter to close this window'
}

function Invoke-PackagePostInstall {
    param(
        $Package
    )

    if (-not $Package.PostInstall) {
        return $true
    }

    $failures = 0
    foreach ($step in $Package.PostInstall) {
        Write-Host "[*] Running post-install: $step" -ForegroundColor DarkGray
        Invoke-Expression $step
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Post-install failed: $step. Exit code:" $LASTEXITCODE -ForegroundColor Red
            $failures++
        }
    }

    return ($failures -eq 0)
}

function Install-SelectedPackage {
    param(
        $Package
    )

    if ($Package.MiseTool) {
        return Install-MiseTool -Name $Package.Name -Tool $Package.MiseTool
    }

    $installed = if ($Package.InstallerUrl) {
        Install-DownloadedPackage -Package $Package
    } else {
        Install-WingetPackage -Id $Package.Id -Name $Package.Name -Source $Package.Source
    }

    if (-not $installed) {
        return $false
    }

    if ($Package.Id -eq 'jdx.mise') {
        Initialize-MiseEnvironment | Out-Null
    }

    if ($Package.PostInstall) {
        if (-not (Invoke-PackagePostInstall -Package $Package)) {
            return $false
        }
    }

    return $true
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Source
    )

    Write-Host "[*] Installing $Name ($Id)..." -ForegroundColor DarkGray

    $wingetArgs = @(
        'install'
        '--id'
        $Id
        '--accept-package-agreements'
        '--accept-source-agreements'
    )

    if ($Source) {
        $wingetArgs += @('-s', $Source)
    } else {
        $wingetArgs += @('-e', '--silent')
    }

    & winget @wingetArgs

    $resolved = Resolve-InstallAppsWingetExitCode -ExitCode $LASTEXITCODE
    if (-not $resolved.IsSuccess) {
        Write-Host "[!] winget install failed for $Name ($Id). $($resolved.Name) (exit $($resolved.ExitCode))" -ForegroundColor Red
        return $false
    }

    Write-Host "[+] $Name installed." -ForegroundColor Green
    return $true
}
#endregion

#region Main
if (-not (Test-WingetAvailable)) {
    Wait-InstallAppsDismiss
    exit 1
}

if (-not (Ensure-InstallAppsWingetAppInstaller)) {
    Wait-InstallAppsDismiss
    exit 1
}

$selectedPackages = ConvertTo-InstallPackageArray (Show-InstallSelectionWindow -Catalog $CategoryCatalog)

if ($selectedPackages.Count -eq 0) {
    Write-Host '[~] No apps selected. Nothing to install.' -ForegroundColor DarkYellow
    Wait-InstallAppsDismiss
    exit 0
}

$failures = 0
$installed = 0
$total = $selectedPackages.Count
Write-Host "[*] Installing $total selected app(s)..." -ForegroundColor DarkGray

foreach ($package in ($selectedPackages | Sort-Object { $_.Name })) {
    if (Install-SelectedPackage -Package $package) {
        $installed++
    } else {
        $failures++
    }
}

if ($failures -eq 0) {
    Write-Host "[+] Installed $installed of $total app(s)." -ForegroundColor Green
} else {
    Write-Host "[~] Installed $installed of $total app(s). $failures failed." -ForegroundColor Yellow
}
Wait-InstallAppsDismiss
#endregion
