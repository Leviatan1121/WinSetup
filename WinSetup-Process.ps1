# WinSetup - child process helpers for the orchestrator (Limited / Elevated).

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
