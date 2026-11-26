# Used by WinSetup.bat only — downloads WinSetup.ps1 from the GitHub release.
param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,
    [Parameter(Mandatory = $true)]
    [string]$Dest
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Initialize-WinSetupHttpTls {
    try {
        $current = [Net.ServicePointManager]::SecurityProtocol
        if (($current -band [Net.SecurityProtocolType]::Tls12) -eq 0) {
            [Net.ServicePointManager]::SecurityProtocol = $current -bor [Net.SecurityProtocolType]::Tls12
        }
    } catch { }
}

Write-Host '[*] Downloading WinSetup.ps1...' -ForegroundColor DarkGray

Initialize-WinSetupHttpTls

$destDir = Split-Path -Parent $Dest
if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

$headers = @{ 'User-Agent' = 'WinSetup' }
$ok = $false
$maxAttempts = 3

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    try {
        & curl.exe -fsSL -A 'WinSetup' -o $Dest $Uri 2>$null
        if ((Test-Path -LiteralPath $Dest) -and (Get-Item -LiteralPath $Dest).Length -gt 0) {
            $ok = $true
        }
    } catch { }
}

for ($attempt = 1; $attempt -le $maxAttempts -and -not $ok; $attempt++) {
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $Dest -UseBasicParsing -Headers $headers
        if ((Test-Path -LiteralPath $Dest) -and (Get-Item -LiteralPath $Dest).Length -gt 0) {
            $ok = $true
        }
    } catch {
        if (Test-Path -LiteralPath $Dest) {
            Remove-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
        }
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

if (-not $ok) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', 'WinSetup')
        $webClient.DownloadFile($Uri, $Dest)
        $ok = (Test-Path -LiteralPath $Dest) -and (Get-Item -LiteralPath $Dest).Length -gt 0
    } catch { }
}

if (-not $ok) {
    Write-Host '[!] Could not download WinSetup.ps1. Check network, proxy, or try again later.' -ForegroundColor Red
    exit 1
}

exit 0