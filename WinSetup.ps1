# WinSetup — main orchestrator. Single UAC at start; one main window; child window per script.
# Entry: WinSetup.bat | irm | iex | .\WinSetup.ps1 (development).

param(
    [string]$OrchestratorMode,
    [string]$ScriptDir
)

if ($OrchestratorMode -and $OrchestratorMode -notin 'Elevated', 'Limited') {
    Write-Error "OrchestratorMode invalido: $OrchestratorMode"
    exit 1
}

$ErrorActionPreference = 'Continue'
$ReleaseBaseUrl = 'https://github.com/Leviatan1121/WinSetup/releases/latest/download'

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
        Write-Warning "$Label termino con codigo $ExitCode."
    }
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

function Start-WinSetupLimitedPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [string]$WorkingDirectory
    )

    $taskName = "WinSetup-Limited-$([guid]::NewGuid().ToString('N'))"
    $doneFile = Join-Path $env:TEMP "$taskName.done"
    $exitFile = Join-Path $env:TEMP "$taskName.exit"
    $wrapperPath = Join-Path $env:TEMP "$taskName.ps1"

    Remove-Item -LiteralPath $doneFile, $exitFile, $wrapperPath -Force -ErrorAction SilentlyContinue

    $argText = ($ArgumentList | ForEach-Object {
        if ($_ -match '\s') { "'$($_ -replace '''', '''''')'" } else { $_ }
    }) -join ', '

    @"
`$ErrorActionPreference = 'Continue'
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass @($argText)
    `$code = `$LASTEXITCODE
    if (`$null -eq `$code) { `$code = 0 }
    if (`$code -ne 0) { exit `$code }
} catch {
    `$code = 1
}
Set-Content -LiteralPath '$exitFile' -Value `$code -Force
Set-Content -LiteralPath '$doneFile' -Value ok -Force
exit `$code
"@ | Set-Content -LiteralPath $wrapperPath -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`""
    if ($WorkingDirectory) {
        $action.WorkingDirectory = $WorkingDirectory
    }

    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null

    try {
        Start-ScheduledTask -TaskName $taskName
        $deadline = (Get-Date).AddHours(2)
        while (-not (Test-Path -LiteralPath $doneFile) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 200
        }
        if (-not (Test-Path -LiteralPath $doneFile)) {
            Write-Warning 'El proceso Limited no termino a tiempo.'
            return 1
        }
        if (Test-Path -LiteralPath $exitFile) {
            return [int](Get-Content -LiteralPath $exitFile -Raw)
        }
        return 0
    }
    finally {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $doneFile, $exitFile, $wrapperPath -Force -ErrorAction SilentlyContinue
    }
}

function Start-WinSetupLimitedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory
    )

    if ($FilePath -like '*.ps1') {
        $psArgs = @('-File', $FilePath) + $ArgumentList
        return Start-WinSetupLimitedPowerShell -ArgumentList $psArgs -WorkingDirectory $WorkingDirectory
    }

    if ($FilePath -like '*.bat' -or $FilePath -like '*.cmd') {
        return Start-WinSetupLimitedPowerShell -ArgumentList @('-Command', "cmd.exe /c `"$FilePath`"") -WorkingDirectory $WorkingDirectory
    }

    return Start-WinSetupLimitedPowerShell -ArgumentList @('-Command', "& `"$FilePath`" $($ArgumentList -join ' ')") -WorkingDirectory $WorkingDirectory
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
        Write-Warning "No se encontro: $TargetPath"
        return 1
    }

    if ($Level -eq 'Elevated') {
        if ($TargetPath -like '*.ps1') {
            $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $TargetPath) + $ArgumentList
            $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WorkingDirectory $WorkingDirectory -Wait -PassThru
            return $proc.ExitCode
        }
        $proc = Start-Process -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -PassThru
        return $proc.ExitCode
    }

    if ($OrchestratorIsAdmin) {
        return Start-WinSetupLimitedProcess -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory
    }

    if ($TargetPath -like '*.ps1') {
        $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $TargetPath) + $ArgumentList
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WorkingDirectory $WorkingDirectory -Wait -PassThru
        return $proc.ExitCode
    }

    $proc = Start-Process -FilePath $TargetPath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -PassThru
    return $proc.ExitCode
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
            Save-WinSetupReleaseFile -Uri "$ReleaseBaseUrl/$file" -Destination $dest
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

if ([string]::IsNullOrWhiteSpace($OrchestratorMode)) {
    New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null

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
    Write-Host '[!] UAC denegado - modo limitado (sin pasos de administrador).' -ForegroundColor Yellow
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
    Write-Host '[!] WinSetup - modo administrador (1 UAC)' -ForegroundColor Cyan
} else {
    Write-Host '[!] WinSetup - modo limitado (sin admin)' -ForegroundColor Cyan
    Write-Host '[~] Se omitiran: winget upgrade/restore, Debloat, Performance (sistema), Remote Support.' -ForegroundColor Yellow
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
                Invoke-WebRequest -Uri $pauserUrl -OutFile $pauserPath -UseBasicParsing
                $exitCode = Start-WinSetupChildProcess `
                    -Level 'Limited' -TargetPath $pauserPath -WorkingDirectory $ScriptDir `
                    -OrchestratorIsAdmin $orchestratorIsAdmin
            }
            'Inline' {
                switch ($step.Id) {
                    'PathHelpers' { Install-WinSetupUserPathHelpers }
                    'Download' { Save-WinSetupReleaseAssets -Dir $ScriptDir }
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
