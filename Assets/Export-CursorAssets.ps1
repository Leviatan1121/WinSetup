# One-time export: run after styling the cursor
$ErrorActionPreference = 'Stop'

$sourceDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$zipPath = Join-Path $PSScriptRoot 'Cursors.zip'

if (-not (Test-Path $sourceDir)) {
    Write-Error "Cursor folder not found: $sourceDir"
}

$files = Get-ChildItem -Path $sourceDir -Filter '*_eoa.cur' -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Error 'No *_eoa.cur files found. Open Settings > Accessibility > Mouse pointer, pick Custom > turquoise, then run this script again.'
}

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path ($files | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Created Cursors.zip ($($files.Count) files):" -ForegroundColor Cyan
Write-Host "  $zipPath" -ForegroundColor Cyan
