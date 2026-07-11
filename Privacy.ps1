#region Privacy > General > Recommendations and offers
Write-Host '[*] Recommendations and advertising ID...' -ForegroundColor DarkGray
$privacyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
Set-ItemProperty -Path $privacyPath -Name 'PersonalizedOffersEnabled' -Value 0 -Type DWord
Set-ItemProperty -Path $privacyPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord

$userProfilePath = 'HKCU:\Control Panel\International\User Profile'
if (-not (Test-Path $userProfilePath)) { New-Item -Path $userProfilePath -Force | Out-Null }
Set-ItemProperty -Path $userProfilePath -Name 'HttpAcceptLanguageOptOut' -Value 1 -Type DWord

$accountNotificationsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
if (-not (Test-Path $accountNotificationsPath)) { New-Item -Path $accountNotificationsPath -Force | Out-Null }
Set-ItemProperty -Path $accountNotificationsPath -Name 'EnableAccountNotifications' -Value 0 -Type DWord

$contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
Set-ItemProperty -Path $contentDelivery -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord

$advertisingPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
if (-not (Test-Path $advertisingPath)) { New-Item -Path $advertisingPath -Force | Out-Null }
Set-ItemProperty -Path $advertisingPath -Name 'Enabled' -Value 0 -Type DWord
#endregion

#region Privacy > Location > App permissions (HKCU)
Write-Host '[*] Location permissions (user)...' -ForegroundColor DarkGray
$locationPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
if (-not (Test-Path $locationPath)) { New-Item -Path $locationPath -Force | Out-Null }
Set-ItemProperty -Path $locationPath -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

$locationNonPackaged = Join-Path $locationPath 'NonPackaged'
if (-not (Test-Path $locationNonPackaged)) { New-Item -Path $locationNonPackaged -Force | Out-Null }
Set-ItemProperty -Path $locationNonPackaged -Name 'Value' -Value 'Deny' -Type String
Set-ItemProperty -Path $locationNonPackaged -Name 'ShowGlobalPrompts' -Value 0 -Type DWord

Get-ChildItem -Path $locationPath -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSChildName -ne 'NonPackaged') {
        Set-ItemProperty -Path $_.PSPath -Name 'Value' -Value 'Deny' -Type String -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}

$locationOverridePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\UserLocationOverridePrivacySetting'
if (-not (Test-Path $locationOverridePath)) { New-Item -Path $locationOverridePath -Force | Out-Null }
Set-ItemProperty -Path $locationOverridePath -Name 'Value' -Value 1 -Type DWord

$locationPolicyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
Set-ItemProperty -Path $locationPolicyPath -Name 'ShowGlobalPrompts' -Value 0 -Type DWord -ErrorAction SilentlyContinue

Get-Process -Name 'SystemSettings' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
#endregion

#region System > Clipboard
Write-Host '[*] Clipboard: local history, no cloud sync...' -ForegroundColor DarkGray
$clipboardPath = 'HKCU:\Software\Microsoft\Clipboard'
if (-not (Test-Path $clipboardPath)) { New-Item -Path $clipboardPath -Force | Out-Null }
Set-ItemProperty -Path $clipboardPath -Name 'EnableClipboardHistory' -Value 1 -Type DWord
Set-ItemProperty -Path $clipboardPath -Name 'EnableCloudClipboard' -Value 0 -Type DWord
#endregion

#region Privacy > Diagnostic data and activity history (HKCU)
Write-Host '[*] Diagnostic data and activity history...' -ForegroundColor DarkGray
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

exit 0
