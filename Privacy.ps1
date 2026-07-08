#region Privacy > General (Recommendations and offers)
$privacyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
Set-ItemProperty -Path $privacyPath -Name 'PersonalizedOffersEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $privacyPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord

$userProfilePath = 'HKCU:\Control Panel\International\User Profile'
if (-not (Test-Path $userProfilePath)) { New-Item -Path $userProfilePath -Force | Out-Null }
Set-ItemProperty -Path $userProfilePath -Name 'HttpAcceptLanguageOptOut' -Value 1 -Type DWord

$explorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty -Path $explorerPath -Name 'Start_TrackProgs' -Value 0 -Type DWord

$accountNotificationsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
if (-not (Test-Path $accountNotificationsPath)) { New-Item -Path $accountNotificationsPath -Force | Out-Null }
Set-ItemProperty -Path $accountNotificationsPath -Name 'EnableAccountNotifications' -Value 0 -Type DWord

$contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
foreach ($name in @(
    'SubscribedContent-338389Enabled',
    'SubscribedContent-338393Enabled',
    'SubscribedContent-353694Enabled',
    'SubscribedContent-353696Enabled'
)) {
    Set-ItemProperty -Path $contentDelivery -Name $name -Value 0 -Type DWord
}

$advertisingPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
if (-not (Test-Path $advertisingPath)) { New-Item -Path $advertisingPath -Force | Out-Null }
Set-ItemProperty -Path $advertisingPath -Name 'Enabled' -Value 0 -Type DWord
#endregion

#region Privacy > Location
$locationPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
if (-not (Test-Path $locationPath)) { New-Item -Path $locationPath -Force | Out-Null }
Set-ItemProperty -Path $locationPath -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

$locationNonPackaged = Join-Path $locationPath 'NonPackaged'
if (-not (Test-Path $locationNonPackaged)) { New-Item -Path $locationNonPackaged -Force | Out-Null }
Set-ItemProperty -Path $locationNonPackaged -Name 'Value' -Value 'Deny' -Type String

$locationOverridePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\UserLocationOverridePrivacySetting'
if (-not (Test-Path $locationOverridePath)) { New-Item -Path $locationOverridePath -Force | Out-Null }
Set-ItemProperty -Path $locationOverridePath -Name 'Value' -Value 1 -Type DWord
#endregion

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "[!] Privacy settings applied successfully." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
