# WinSetup — winget helpers (version queries, exit codes, silent uninstall).

function Get-WinSetupAppInstallerVersion {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $null
    }

    try {
        $lines = & winget list -e --id Microsoft.AppInstaller --accept-source-agreements 2>&1
        foreach ($line in @($lines)) {
            $text = [string]$line
            if ($text -match 'Microsoft\.AppInstaller' -and $text -match '(\d+(?:\.\d+){2,3})') {
                return $Matches[1]
            }
        }
    } catch {
        return $null
    }

    return $null
}

function Get-WinSetupAppInstallerAvailableVersion {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $null
    }

    try {
        $lines = & winget show -e --id Microsoft.AppInstaller --accept-source-agreements 2>&1
        foreach ($line in @($lines)) {
            $text = [string]$line
            if ($text -match '^\s*Version\s*:\s*(.+)$') {
                return $Matches[1].Trim()
            }
        }
    } catch {
        return $null
    }

    return $null
}

function Resolve-WinSetupWingetExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

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

    $benign = $normalized -in @(
        0
        [int32]0x8A15002B
        [int32]0x8A15004F
    )

    $benignUninstall = $normalized -in @(
        0
        [int32]0x8A150014
    )

    return [PSCustomObject]@{
        ExitCode          = $normalized
        Hex               = $hex
        Name              = $name
        IsBenign          = $benign
        IsBenignUninstall = $benignUninstall
        IsSuccess         = ($normalized -eq 0)
    }
}

function Invoke-WinSetupWingetUninstall {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$WingetArgs
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return 0
    }

    $exitCode = 0
    $null = & winget uninstall @WingetArgs 2>&1
    if ($null -ne $LASTEXITCODE) {
        $exitCode = $LASTEXITCODE
    }

    $resolved = Resolve-WinSetupWingetExitCode -ExitCode $exitCode
    if ($resolved.IsBenignUninstall) {
        return 0
    }

    return $resolved.ExitCode
}
