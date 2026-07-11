# WinSetup — main orchestrator. Single UAC at start; one main window; child window per script.
# Entry: WinSetup.bat | irm | iex | .\WinSetup.ps1 (development).

param(
    [string]$OrchestratorMode,
    [string]$ScriptDir
)

if ($OrchestratorMode -and $OrchestratorMode -notin 'Elevated', 'Limited') {
    Write-Error "Invalid OrchestratorMode: $OrchestratorMode"
    exit 1
}

$ErrorActionPreference = 'Continue'
$ReleaseBaseUrl = 'https://github.com/Leviatan1121/WinSetup/releases/latest/download'
$script:WinSetupProgressLength = 0

function Write-WinSetupProgressLine {
    param([string]$Message)
    $pad = if ($Message.Length -lt $script:WinSetupProgressLength) {
        ' ' * ($script:WinSetupProgressLength - $Message.Length)
    } else { '' }
    Write-Host "`r$Message$pad" -NoNewline -ForegroundColor DarkGray
    $script:WinSetupProgressLength = $Message.Length
}

function Clear-WinSetupProgressLine {
    if ($script:WinSetupProgressLength -gt 0) {
        Write-Host (' ' * $script:WinSetupProgressLength + "`r") -NoNewline
        $script:WinSetupProgressLength = 0
    }
}

function Get-WinSetupDefaultScriptDir {
    if ($env:WINSETUP_LOCAL -eq '1' -and $PSScriptRoot) {
        return $PSScriptRoot
    }
    return Join-Path $env:TEMP 'WinSetup'
}

function Get-WinSetupEntryScriptPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dir
    )

    if ($PSCommandPath) {
        return $PSCommandPath
    }

    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $savedScript = Join-Path $Dir 'WinSetup.ps1'

    $inMemoryScript = $MyInvocation.MyCommand.Definition
    if ($inMemoryScript -and $inMemoryScript.Length -gt 1024) {
        Write-Host '[*] Persisting WinSetup.ps1 for bootstrap (irm/iex in-memory)...' -ForegroundColor DarkGray
        Set-Content -LiteralPath $savedScript -Value $inMemoryScript -Encoding UTF8
        return $savedScript
    }

    Write-Host '[*] Persisting WinSetup.ps1 for bootstrap (download)...' -ForegroundColor DarkGray
    Save-WinSetupReleaseFile -Uri "$ReleaseBaseUrl/WinSetup.ps1" -Destination $savedScript
    return $savedScript
}

function Test-WinSetupIsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-WinSetupStepHeader {
    param([int]$Index, [int]$Total, [string]$Label, [string]$Level)
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "[*] Step $Index/$Total`: $Label ($Level)..." -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
}

function Write-WinSetupStepResult {
    param([string]$Label, [int]$ExitCode, [switch]$Skipped)
    if ($Skipped) {
        Write-Host "[~] $Label skipped (requires admin)." -ForegroundColor Yellow
        return
    }
    if ($ExitCode -eq 0) {
        Write-Host "[+] $Label completed (exit 0)." -ForegroundColor Green
    } else {
        Write-Warning "$Label finished with exit code $ExitCode."
    }
}

function Get-WinSetupPausedPs1LaunchArgs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [string[]]$ArgumentList = @()
    )

    $targetEscaped = $TargetPath -replace "'", "''"
    if ($ArgumentList -and $ArgumentList.Count -gt 0) {
        $escapedArgs = ($ArgumentList | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ', '
        $invokeLine = "& '$targetEscaped' @($escapedArgs)"
    } else {
        $invokeLine = "& '$targetEscaped'"
    }

    $command = @"
`$ErrorActionPreference = 'Continue'
`$code = 0
try {
    $invokeLine
} catch {
    `$code = 1
}
Read-Host 'Press Enter to close this window'
exit `$code
"@

    return @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command)
}

function Save-WinSetupReleaseFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
}

function Get-WinSetupPauserMarkerPath {
    param([Parameter(Mandatory = $true)][string]$Dir)
    return Join-Path $Dir '.winsetup-pauser-done'
}

function Test-WinSetupPauserDone {
    param([Parameter(Mandatory = $true)][string]$Dir)
    return Test-Path -LiteralPath (Get-WinSetupPauserMarkerPath -Dir $Dir)
}

function Set-WinSetupPauserDone {
    param([Parameter(Mandatory = $true)][string]$Dir)
    Set-Content -LiteralPath (Get-WinSetupPauserMarkerPath -Dir $Dir) -Value (Get-Date).ToUniversalTime().ToString('o') -Force
}

function Invoke-WinSetupPauser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dir,
        [bool]$RunAsUser = $false
    )

    $pauserUrl = 'https://github.com/Leviatan1121/WindowsUpdatePauser/releases/latest/download/WindowsUpdatePauser.bat'
    $pauserPath = Join-Path $Dir 'WindowsUpdatePauser.bat'

    Write-WinSetupProgressLine '[*] Downloading Windows Update Pauser...'
    Save-WinSetupReleaseFile -Uri $pauserUrl -Destination $pauserPath

    Write-WinSetupProgressLine '[*] Running Windows Update Pauser (close its window when finished)...'
    if ($RunAsUser) {
        $exitCode = Start-WinSetupUserContextProcess -FilePath $pauserPath -WorkingDirectory $Dir
    } else {
        $proc = Start-Process -FilePath $pauserPath -WorkingDirectory $Dir -Wait -PassThru
        $exitCode = $proc.ExitCode
    }

    Set-WinSetupPauserDone -Dir $Dir
    return $exitCode
}

function Start-WinSetupUserContextProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory
    )

    if ($FilePath -like '*.ps1') {
        $psArgs = Get-WinSetupPausedPs1LaunchArgs -TargetPath $FilePath -ArgumentList $ArgumentList
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WorkingDirectory $WorkingDirectory -Wait -PassThru
        return $proc.ExitCode
    }

    if ($FilePath -like '*.bat' -or $FilePath -like '*.cmd') {
        $proc = Start-Process -FilePath $FilePath -WorkingDirectory $WorkingDirectory -Wait -PassThru
        return $proc.ExitCode
    }

    $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -PassThru
    return $proc.ExitCode
}

function Start-WinSetupChildProcess {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Limited', 'Elevated')]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory,
        [bool]$OrchestratorIsAdmin
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Write-Warning "Not found: $TargetPath"
        return 1
    }

    if ($Level -eq 'Elevated') {
        if ($TargetPath -like '*.ps1') {
            $psArgs = Get-WinSetupPausedPs1LaunchArgs -TargetPath $TargetPath -ArgumentList $ArgumentList
            $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WorkingDirectory $WorkingDirectory -Wait -PassThru
            return $proc.ExitCode
        }
        $proc = Start-Process -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -PassThru
        return $proc.ExitCode
    }

    if ($OrchestratorIsAdmin) {
        return Start-WinSetupUserContextProcess -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory
    }

    return Start-WinSetupUserContextProcess -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory
}

function Install-WinSetupUserPathHelpers {
    $BinDir = Join-Path $env:USERPROFILE 'bin'
    if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }

    Set-Content -Path (Join-Path $BinDir 'AllowFile.bat') -Value @(
        '@echo off'
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%~f1"'
    )

    Set-Content -Path (Join-Path $BinDir 'AllowProcess.bat') -Value "@echo off`npowershell -NoExit -NoProfile -ExecutionPolicy Bypass"

    $UserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($UserPath -notlike "*$BinDir*") {
        [Environment]::SetEnvironmentVariable('PATH', "$UserPath;$BinDir", 'User')
    }

    Write-Host '[+] Environment configured (%USERPROFILE%\bin + PATH).' -ForegroundColor Green
}

function Get-WinSetupReleaseAssets {
    return @(
        'Configure.ps1', 'Privacy.ps1', 'Performance.ps1',
        'Install-MousePointerPrompt.ps1', 'Open-MousePointerSettings.ps1',
        'Install-AppsPrompt.ps1', 'Open-InstallApps.ps1', 'InstallApps.ps1',
        'WinSetup-AI-UpdateCleanup.ps1', 'WinSetup-Process.ps1',
        'WinSetup-WingetUpgrade.ps1', 'WinSetup-WingetHelpers.ps1',
        'Debloat.ps1', 'RemoteSupport.ps1'
    )
}

function Save-WinSetupReleaseAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dir,
        [string]$ProgressLabel = '[*] Downloading {0}...'
    )

    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $useLocal = ($env:WINSETUP_LOCAL -eq '1')
    $downloaded = 0
    $failed = 0
    $skipped = 0

    foreach ($file in (Get-WinSetupReleaseAssets)) {
        $dest = Join-Path $Dir $file
        $localSource = Join-Path $PSScriptRoot $file

        if ($useLocal -and (Test-Path -LiteralPath $localSource)) {
            Write-WinSetupProgressLine ($ProgressLabel -f "$file (local)")
            Copy-Item -LiteralPath $localSource -Destination $dest -Force
            $downloaded++
            continue
        }

        Write-WinSetupProgressLine ($ProgressLabel -f $file)

        try {
            Save-WinSetupReleaseFile -Uri "$ReleaseBaseUrl/$file" -Destination $dest
            $downloaded++
        } catch {
            Write-Host ''
            Write-Warning "Failed to download ${file}: $($_.Exception.Message)"
            $failed++
        }
    }

    return @{
        Downloaded = $downloaded
        Failed     = $failed
        Skipped    = $skipped
    }
}

function Get-WinSetupStepManifest {
    return @(
        @{ Id = 'Pauser';           Label = 'Windows Update Pauser';              Level = 'Limited';  Type = 'External' }
        @{ Id = 'PathHelpers';      Label = 'User PATH helpers';                  Level = 'Inline';   Type = 'Inline' }
        @{ Id = 'Download';         Label = 'Download release assets';            Level = 'Inline';   Type = 'Inline' }
        @{ Id = 'Configure';        Label = 'Configure.ps1';                      Level = 'Limited';  Type = 'Script'; Script = 'Configure.ps1' }
        @{ Id = 'Privacy';          Label = 'Privacy.ps1';                        Level = 'Limited';  Type = 'Script'; Script = 'Privacy.ps1' }
        @{ Id = 'Performance';      Label = 'Performance.ps1';                    Level = 'Limited';  Type = 'Script'; Script = 'Performance.ps1' }
        @{ Id = 'WingetUpgrade';    Label = 'WinSetup-WingetUpgrade.ps1';         Level = 'Elevated'; Type = 'Script'; Script = 'WinSetup-WingetUpgrade.ps1'; RequiresAdmin = $true }
        @{ Id = 'Debloat';          Label = 'Debloat.ps1';                        Level = 'Elevated'; Type = 'Script'; Script = 'Debloat.ps1'; Args = @('-WinSetupElevated'); RequiresAdmin = $true }
        @{ Id = 'PerformanceSys';   Label = 'Performance.ps1 -SystemOnly';        Level = 'Elevated'; Type = 'Script'; Script = 'Performance.ps1'; Args = @('-SystemOnly'); RequiresAdmin = $true }
        @{ Id = 'MouseHook';        Label = 'Install-MousePointerPrompt.ps1';     Level = 'Limited';  Type = 'Script'; Script = 'Install-MousePointerPrompt.ps1'; Args = @('-Register') }
        @{ Id = 'AppsHook';         Label = 'Install-AppsPrompt.ps1';             Level = 'Limited';  Type = 'Script'; Script = 'Install-AppsPrompt.ps1'; Args = @('-Register') }
        @{ Id = 'RemoteSupport';    Label = 'RemoteSupport.ps1';                  Level = 'Elevated'; Type = 'Script'; Script = 'RemoteSupport.ps1'; Args = @('-WinSetupElevated'); RequiresAdmin = $true }
    )
}

#region Bootstrap — single UAC handoff
if (-not $ScriptDir) {
    $ScriptDir = Get-WinSetupDefaultScriptDir
}

if ([string]::IsNullOrWhiteSpace($OrchestratorMode)) {
    New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null
    Remove-Item -LiteralPath (Get-WinSetupPauserMarkerPath -Dir $ScriptDir) -Force -ErrorAction SilentlyContinue

    $entryScript = Get-WinSetupEntryScriptPath -Dir $ScriptDir

    $elevArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $entryScript,
        '-OrchestratorMode', 'Elevated',
        '-ScriptDir', $ScriptDir
    )

    try {
        $proc = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -ArgumentList $elevArgs
        if ($proc) { exit 0 }
    } catch [System.ComponentModel.Win32Exception] {
        if ($_.NativeErrorCode -ne 1223) {
            Write-Warning "UAC elevation failed: $($_.Exception.Message)"
        }
    } catch {
        Write-Warning "UAC elevation failed: $($_.Exception.Message)"
    }

    Write-Host '=========================================================' -ForegroundColor Yellow
    Write-Host '[!] UAC denied - running in limited mode (no admin steps).' -ForegroundColor Yellow
    Write-Host '=========================================================' -ForegroundColor Yellow
    $OrchestratorMode = 'Limited'
}
#endregion

$orchestratorIsAdmin = ($OrchestratorMode -eq 'Elevated') -and (Test-WinSetupIsAdmin)
if ($OrchestratorMode -eq 'Elevated' -and -not $orchestratorIsAdmin) {
    Write-Error 'OrchestratorMode Elevated requires an administrator session.'
    exit 1
}

Write-Host '=========================================================' -ForegroundColor Cyan
if ($orchestratorIsAdmin) {
    Write-Host '[!] WinSetup - administrator mode (single UAC)' -ForegroundColor Cyan
} else {
    Write-Host '[!] WinSetup - limited mode (no admin)' -ForegroundColor Cyan
    Write-Host '[~] Skipping: winget upgrade, Debloat, Performance (system), Remote Support.' -ForegroundColor Yellow
}
Write-Host '=========================================================' -ForegroundColor Cyan

$steps = Get-WinSetupStepManifest
$total = $steps.Count
$index = 0
$skippedAdmin = [System.Collections.Generic.List[string]]::new()

foreach ($step in $steps) {
    $index++
    $requiresAdmin = [bool]$step.RequiresAdmin
    $skip = $requiresAdmin -and -not $orchestratorIsAdmin

    if ($skip) {
        $skippedAdmin.Add($step.Label)
        Write-WinSetupStepHeader -Index $index -Total $total -Label $step.Label -Level 'Skipped'
        Write-WinSetupStepResult -Label $step.Label -ExitCode 0 -Skipped
        continue
    }

    if ($step.Id -eq 'Pauser' -and (Test-WinSetupPauserDone -Dir $ScriptDir)) {
        Write-WinSetupStepHeader -Index $index -Total $total -Label $step.Label -Level 'Skipped'
        Write-Host '[~] Already run in this session.' -ForegroundColor DarkGray
        Write-WinSetupStepResult -Label $step.Label -ExitCode 0
        continue
    }

    Write-WinSetupStepHeader -Index $index -Total $total -Label $step.Label -Level $step.Level

    $exitCode = 0
    $downloadStats = $null
    try {
        switch ($step.Type) {
            'External' {
                $exitCode = Invoke-WinSetupPauser -Dir $ScriptDir -RunAsUser:$orchestratorIsAdmin
            }
            'Inline' {
                switch ($step.Id) {
                    'PathHelpers' { Install-WinSetupUserPathHelpers }
                    'Download' {
                        $downloadStats = Save-WinSetupReleaseAssets -Dir $ScriptDir
                        if ($downloadStats.Failed -gt 0) { $exitCode = 1 }
                    }
                }
            }
            'Script' {
                $scriptPath = Join-Path $ScriptDir $step.Script
                $args = @()
                if ($step.Args) { $args += $step.Args }
                if ($step.Script -match 'Prompt\.ps1$') {
                    $args += @('-SourceDir', $ScriptDir)
                }
                $exitCode = Start-WinSetupChildProcess `
                    -Level $step.Level `
                    -TargetPath $scriptPath `
                    -ArgumentList $args `
                    -WorkingDirectory $ScriptDir `
                    -OrchestratorIsAdmin $orchestratorIsAdmin
            }
        }
    } catch {
        Write-Warning "$($step.Label) failed: $($_.Exception.Message)"
        $exitCode = 1
    }

    if ($step.Id -eq 'Pauser') {
        Clear-WinSetupProgressLine
        Write-WinSetupStepResult -Label $step.Label -ExitCode $exitCode
        Write-Host '=========================================================' -ForegroundColor Cyan
    } elseif ($step.Id -eq 'Download' -and $downloadStats) {
        Clear-WinSetupProgressLine
        if ($downloadStats.Failed -gt 0) {
            Write-Host "[~] Downloaded $($downloadStats.Downloaded) assets; $($downloadStats.Failed) failed (exit $exitCode)." -ForegroundColor Yellow
        } else {
            Write-Host "[+] Downloaded $($downloadStats.Downloaded) assets (exit $exitCode)." -ForegroundColor Green
        }
        Write-Host '=========================================================' -ForegroundColor Cyan
    } else {
        Write-WinSetupStepResult -Label $step.Label -ExitCode $exitCode
    }
}

Write-Host '=========================================================' -ForegroundColor Yellow
Write-Host '[!] Baseline complete. Sign out and back in (or reboot)' -ForegroundColor Yellow
Write-Host '    so Performance preset shows correctly in sysdm.cpl.' -ForegroundColor Yellow
Write-Host '    After reboot: Settings opens to Mouse pointer (pick your color).' -ForegroundColor Yellow
Write-Host '    After reboot: InstallApps opens to select software to install.' -ForegroundColor Yellow
if ($orchestratorIsAdmin) {
    Write-Host '    If RDP uninstall prompted for restart, reboot when ready.' -ForegroundColor Yellow
}
if ($skippedAdmin.Count -gt 0) {
    Write-Host '[~] Steps skipped (no admin):' -ForegroundColor Yellow
    foreach ($name in $skippedAdmin) {
        Write-Host "    - $name" -ForegroundColor Yellow
    }
}
Write-Host '=========================================================' -ForegroundColor Yellow

Read-Host 'Press Enter to continue'
