# WinSetup — one-time dev utility to package *_eoa.cur files for Cursors.zip.
# Prerequisite: Settings > Accessibility > Mouse pointer > Custom > pick your color.
# Custom colors need these files once; white/black/inverted need no zip (registry only).

$ErrorActionPreference = 'Stop'

#region Source validation
$sourceDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$zipPath = Join-Path $PSScriptRoot 'Cursors.zip'

if (-not (Test-Path $sourceDir)) {
    Write-Error "Cursor folder not found: $sourceDir"
}

$files = Get-ChildItem -Path $sourceDir -Filter '*_eoa.cur' -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Error 'No *_eoa.cur files found. Open Settings > Accessibility > Mouse pointer, pick Custom > turquoise, then run this script again.'
}
#endregion

#region Create archive
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path ($files | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -CompressionLevel Optimal
#endregion

Write-Host "Created Cursors.zip ($($files.Count) files):" -ForegroundColor Cyan
Write-Host "  $zipPath" -ForegroundColor Cyan
