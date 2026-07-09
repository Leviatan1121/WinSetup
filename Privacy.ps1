# WinSetup — privacy and recommendations (HKCU).
# Settings: Privacy & security. Requires no elevation.
# Run order: Setup.bat → Configure.ps1 → Privacy.ps1 → Debloat.ps1 → Performance.ps1

#region Privacy > General > Recommendations and offers
# Personalized offers, tailored experiences, and language-list sharing.
$privacyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
Set-ItemProperty -Path $privacyPath -Name 'PersonalizedOffersEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $privacyPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord

$userProfilePath = 'HKCU:\Control Panel\International\User Profile'
if (-not (Test-Path $userProfilePath)) { New-Item -Path $userProfilePath -Force | Out-Null }
Set-ItemProperty -Path $userProfilePath -Name 'HttpAcceptLanguageOptOut' -Value 1 -Type DWord

# Settings app: account notifications and in-app recommendations.
$accountNotificationsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
if (-not (Test-Path $accountNotificationsPath)) { New-Item -Path $accountNotificationsPath -Force | Out-Null }
Set-ItemProperty -Path $accountNotificationsPath -Name 'EnableAccountNotifications' -Value 0 -Type DWord

$contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
# 338389 only here; other SubscribedContent keys are set in Configure.ps1 (Start recommendations).
Set-ItemProperty -Path $contentDelivery -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord

# Advertising ID for apps.
$advertisingPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
if (-not (Test-Path $advertisingPath)) { New-Item -Path $advertisingPath -Force | Out-Null }
Set-ItemProperty -Path $advertisingPath -Name 'Enabled' -Value 0 -Type DWord
#endregion

#region Privacy > Location > App permissions (HKCU)
# Per-user consent store. System-wide location OFF is handled in Debloat.ps1 (elevated).
$locationPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
if (-not (Test-Path $locationPath)) { New-Item -Path $locationPath -Force | Out-Null }
Set-ItemProperty -Path $locationPath -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

# Classic (non-Store) desktop apps.
$locationNonPackaged = Join-Path $locationPath 'NonPackaged'
if (-not (Test-Path $locationNonPackaged)) { New-Item -Path $locationNonPackaged -Force | Out-Null }
Set-ItemProperty -Path $locationNonPackaged -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationNonPackaged -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

# Any already-installed packaged apps with a per-app subkey.
Get-ChildItem -Path $locationPath -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSChildName -ne 'NonPackaged') {
        Set-ItemProperty -Path $_.PSPath -Name 'Value' -Value 'Deny' -Type String -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}

# Allow location override (invalidation) — user-controlled spoofing, separate from service toggle.
$locationOverridePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\UserLocationOverridePrivacySetting'
if (-not (Test-Path $locationOverridePath)) { New-Item -Path $locationOverridePath -Force | Out-Null }
Set-ItemProperty -Path $locationOverridePath -Name 'Value' -Value 1 -Type DWord

# Parent ConsentStore: suppress global location prompts.
$locationPolicyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
Set-ItemProperty -Path $locationPolicyPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord -ErrorAction SilentlyContinue

# Force Settings to reload location page on next open.
Get-Process -Name 'SystemSettings' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#endregion

#region System > Clipboard
# Local history ON; cloud sync OFF (Settings > System > Clipboard).
$clipboardPath = 'HKCU:\Software\Microsoft\Clipboard'
if (-not (Test-Path $clipboardPath)) { New-Item -Path $clipboardPath -Force | Out-Null }
Set-ItemProperty -Path $clipboardPath -Name 'EnableClipboardHistory' -Value 1 -Type DWord
Set-ItemProperty -Path $clipboardPath -Name 'EnableCloudClipboard' -Value 0 -Type DWord
#endregion

#region Privacy > Diagnostic data and activity history (HKCU)
Set-ItemProperty -Path $privacyPath -Name 'PublishUserActivities' -Value 0 -Type DWord

$siufPath = 'HKCU:\Software\Microsoft\Siuf\Rules'
if (-not (Test-Path $siufPath)) { New-Item -Path $siufPath -Force | Out-Null }
Set-ItemProperty -Path $siufPath -Name 'NumberOfSIUFInPeriod' -Value 0 -Type DWord
Set-ItemProperty -Path $siufPath -Name 'PeriodInDays' -Value 0 -Type DWord

$inputPersonalization = 'HKCU:\Software\Microsoft\InputPersonalization'
if (-not (Test-Path $inputPersonalization)) { New-Item -Path $inputPersonalization -Force | Out-Null }
Set-ItemProperty -Path $inputPersonalization -Name 'RestrictImplicitInkCollection' -Value 1 -Type DWord
Set-ItemProperty -Path $inputPersonalization -Name 'RestrictImplicitTextCollection' -Value 1 -Type DWord

$trainedDataStore = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'
if (-not (Test-Path $trainedDataStore)) { New-Item -Path $trainedDataStore -Force | Out-Null }
Set-ItemProperty -Path $trainedDataStore -Name 'HarvestContacts' -Value 0 -Type DWord
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Privacy settings applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
