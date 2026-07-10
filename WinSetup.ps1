# WinSetup — main orchestrator. Single UAC at start; one main window; child window per script.
# Entry: WinSetup.bat (downloads this file) or .\WinSetup.ps1 (development).

param(
    [ValidateSet('Elevated', 'Limited')]
    [string]$OrchestratorMode,
    [string]$ScriptDir
)

$ErrorActionPreference = 'Continue'
$ReleaseBaseUrl = 'https://github.com/Leviatan1121/WinSetup/releases/latest/download'

function Get-WinSetupDefaultScriptDir {
    if ($env:WINSETUP_LOCAL -eq '1' -and $PSScriptRoot) {
        return $PSScriptRoot
    }
    return Join-Path $env:TEMP 'WinSetup'
}

function Test-WinSetupIsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-WinSetupStepHeader {
    param([int]$Index, [int]$Total, [string]$Label, [string]$Level)
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "[*] Paso $Index/$Total`: $Label ($Level)..." -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
}

function Write-WinSetupStepResult {
    param([string]$Label, [int]$ExitCode, [switch]$Skipped)
    if ($Skipped) {
        Write-Host "[~] $Label omitido (requiere admin)." -ForegroundColor Yellow
        return
    }
    if ($ExitCode -eq 0) {
        Write-Host "[+] $Label completado (exit 0)." -ForegroundColor Green
    } else {
        Write-Warning "$Label terminó con código $ExitCode."
    }
}

function Import-WinSetupProcessModule {
    param([string]$Dir)

    foreach ($candidate in @(
        (Join-Path $Dir 'WinSetup-Process.ps1'),
        (Join-Path $PSScriptRoot 'WinSetup-Process.ps1')
    )) {
        if (Test-Path -LiteralPath $candidate) {
            . $candidate
            return $true
        }
    }
    return $false
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
        'WinSetup-WingetUpgrade.ps1', 'WinSetup-WingetRestorePinning.ps1',
        'Debloat.ps1', 'RemoteSupport.ps1'
    )
}

function Save-WinSetupReleaseAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dir
    )

    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $useLocal = ($env:WINSETUP_LOCAL -eq '1')

    foreach ($file in (Get-WinSetupReleaseAssets)) {
        $dest = Join-Path $Dir $file
        $localSource = Join-Path $PSScriptRoot $file

        if ($useLocal -and (Test-Path -LiteralPath $localSource)) {
            Copy-Item -LiteralPath $localSource -Destination $dest -Force
            Write-Host "[*] Using local $file" -ForegroundColor DarkGray
            continue
        }

        Write-Host "[*] Downloading $file..." -ForegroundColor DarkGray
        try {
            Invoke-RestMethod -Uri "$ReleaseBaseUrl/$file" -OutFile $dest
        } catch {
            Write-Warning "Failed to download ${file}: $($_.Exception.Message)"
        }
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
        @{ Id = 'WingetRestore';    Label = 'WinSetup-WingetRestorePinning.ps1';  Level = 'Limited';  Type = 'Script'; Script = 'WinSetup-WingetRestorePinning.ps1'; RequiresAdmin = $true }
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

if (-not $OrchestratorMode) {
    New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null

    $elevArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath,
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
    Write-Host '[!] UAC denegado — modo limitado (sin pasos de administrador).' -ForegroundColor Yellow
    Write-Host '=========================================================' -ForegroundColor Yellow
    $OrchestratorMode = 'Limited'
}
#endregion

$orchestratorIsAdmin = ($OrchestratorMode -eq 'Elevated') -and (Test-WinSetupIsAdmin)
if ($OrchestratorMode -eq 'Elevated' -and -not $orchestratorIsAdmin) {
    Write-Error 'OrchestratorMode Elevated requires an administrator session.'
    exit 1
}

Import-WinSetupProcessModule -Dir $ScriptDir | Out-Null
if (-not (Get-Command Start-WinSetupChildProcess -ErrorAction SilentlyContinue)) {
    $earlyModule = Join-Path $ScriptDir 'WinSetup-Process.ps1'
    if (-not (Test-Path -LiteralPath $earlyModule)) {
        try {
            Invoke-RestMethod -Uri "$ReleaseBaseUrl/WinSetup-Process.ps1" -OutFile $earlyModule
        } catch {
            Write-Warning "Could not pre-download WinSetup-Process.ps1: $($_.Exception.Message)"
        }
    }
    Import-WinSetupProcessModule -Dir $ScriptDir | Out-Null
}

Write-Host '=========================================================' -ForegroundColor Cyan
if ($orchestratorIsAdmin) {
    Write-Host '[!] WinSetup — modo administrador (1 UAC)' -ForegroundColor Cyan
} else {
    Write-Host '[!] WinSetup — modo limitado (sin admin)' -ForegroundColor Cyan
    Write-Host '[~] Se omitirán: winget upgrade/restore, Debloat, Performance (sistema), Remote Support.' -ForegroundColor Yellow
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
        Write-WinSetupStepHeader -Index $index -Total $total -Label $step.Label -Level 'Omitido'
        Write-WinSetupStepResult -Label $step.Label -ExitCode 0 -Skipped
        continue
    }

    Write-WinSetupStepHeader -Index $index -Total $total -Label $step.Label -Level $step.Level

    $exitCode = 0
    try {
        switch ($step.Type) {
            'External' {
                $pauserUrl = 'https://github.com/Leviatan1121/WindowsUpdatePauser/releases/latest/download/WindowsUpdatePauser.bat'
                $pauserPath = Join-Path $ScriptDir 'WindowsUpdatePauser.bat'
                Invoke-RestMethod -Uri $pauserUrl -OutFile $pauserPath
                if (Get-Command Start-WinSetupChildProcess -ErrorAction SilentlyContinue) {
                    $exitCode = Start-WinSetupChildProcess `
                        -Level 'Limited' -TargetPath $pauserPath -WorkingDirectory $ScriptDir `
                        -OrchestratorIsAdmin $orchestratorIsAdmin
                } else {
                    $proc = Start-Process -FilePath $pauserPath -WorkingDirectory $ScriptDir -Wait -PassThru
                    $exitCode = $proc.ExitCode
                }
            }
            'Inline' {
                switch ($step.Id) {
                    'PathHelpers' { Install-WinSetupUserPathHelpers }
                    'Download' {
                        Save-WinSetupReleaseAssets -Dir $ScriptDir
                        Import-WinSetupProcessModule -Dir $ScriptDir | Out-Null
                        if (-not (Get-Command Start-WinSetupChildProcess -ErrorAction SilentlyContinue)) {
                            Write-Warning 'WinSetup-Process.ps1 missing after download — child scripts may fail.'
                        }
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
                if (-not (Get-Command Start-WinSetupChildProcess -ErrorAction SilentlyContinue)) {
                    throw 'Start-WinSetupChildProcess not available — run Download step first or set WINSETUP_LOCAL=1.'
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

    Write-WinSetupStepResult -Label $step.Label -ExitCode $exitCode
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
    Write-Host '[~] Pasos omitidos por falta de admin:' -ForegroundColor Yellow
    foreach ($name in $skippedAdmin) {
        Write-Host "    - $name" -ForegroundColor Yellow
    }
}
Write-Host '=========================================================' -ForegroundColor Yellow

Read-Host 'Presione Enter para continuar'
