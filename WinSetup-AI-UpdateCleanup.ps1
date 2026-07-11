# WinSetup — all anti-AI removal (Copilot, Recall, integrated AI, post-update persistence).
# Called once from Debloat.ps1; scheduled task re-runs removal after Windows updates.

$helpersPath = Join-Path $PSScriptRoot 'WinSetup-WingetHelpers.ps1'
if (Test-Path -LiteralPath $helpersPath) {
    . $helpersPath
}

function Get-WinSetupOSBuild {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion')
    try {
        return "$($key.GetValue('CurrentBuild')).$($key.GetValue('UBR'))"
    } finally {
        $key.Close()
    }
}

function Get-WinSetupCachedBuild {
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\WinSetup')
        try {
            return [string]$key.GetValue('CachedBuild')
        } finally {
            $key.Close()
        }
    } catch {
        return $null
    }
}

function Set-WinSetupCachedBuild {
    param([string]$Build = (Get-WinSetupOSBuild))
    if (-not (Test-Path 'HKLM:\SOFTWARE\WinSetup')) {
        New-Item -Path 'HKLM:\SOFTWARE\WinSetup' -Force | Out-Null
    }
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\WinSetup' -Name 'CachedBuild' -Value $Build -Type String
}

function Test-WinSetupOSBuildChanged {
    return ((Get-WinSetupCachedBuild) -ne (Get-WinSetupOSBuild))
}

function Remove-WinSetupLockedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    & takeown.exe /f $Path /a /r /d y 2>$null | Out-Null
    & icacls.exe $Path /grant '*S-1-5-32-544:F' /t /c 2>$null | Out-Null
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
}

function Set-WinSetupAIPolicies {
    $explorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $explorerPath -Name 'ShowCopilotButton' -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $explorerPath -Name 'TaskbarCompanion' -Value 0 -Type DWord -ErrorAction SilentlyContinue

    $auxPinsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins'
    if (-not (Test-Path $auxPinsPath)) { New-Item -Path $auxPinsPath -Force | Out-Null }
    Set-ItemProperty -Path $auxPinsPath -Name 'CopilotPWAPin' -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $auxPinsPath -Name 'RecallPin' -Value 0 -Type DWord -ErrorAction SilentlyContinue

    Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI\LastConfiguration' -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($hive in @('HKLM:\SOFTWARE\Policies', 'HKCU:\Software\Policies')) {
        $copilotPath = "$hive\Microsoft\Windows\WindowsCopilot"
        if (-not (Test-Path $copilotPath)) { New-Item -Path $copilotPath -Force | Out-Null }
        Set-ItemProperty -Path $copilotPath -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord

        $aiPath = "$hive\Microsoft\Windows\WindowsAI"
        if (-not (Test-Path $aiPath)) { New-Item -Path $aiPath -Force | Out-Null }
        Set-ItemProperty -Path $aiPath -Name 'RemoveMicrosoftCopilotApp' -Value 1 -Type DWord
        Set-ItemProperty -Path $aiPath -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord
        Set-ItemProperty -Path $aiPath -Name 'DisableClickToDo' -Value 1 -Type DWord
    }

    $windowsAiPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    if (-not (Test-Path $windowsAiPolicy)) { New-Item -Path $windowsAiPolicy -Force | Out-Null }
    foreach ($policyName in @(
        'AllowRecallEnablement'
        'TurnOffSavingSnapshots'
        'DisableSettingsAgent'
        'DisableAgentConnectors'
        'DisableAgentWorkspaces'
        'DisableRemoteAgentConnectors'
    )) {
        $policyValue = if ($policyName -eq 'AllowRecallEnablement') { 0 } else { 1 }
        Set-ItemProperty -Path $windowsAiPolicy -Name $policyName -Value $policyValue -Type DWord
    }

    $copilotKeyPolicy = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CopilotKey'
    if (-not (Test-Path $copilotKeyPolicy)) { New-Item -Path $copilotKeyPolicy -Force | Out-Null }
    Set-ItemProperty -Path $copilotKeyPolicy -Name 'SetCopilotHardwareKey' -Value ' ' -Type String

    foreach ($shellRoot in @('HKLM:\SOFTWARE', 'HKCU:\Software')) {
        $shellCopilot = "$shellRoot\Microsoft\Windows\Shell\Copilot"
        if (-not (Test-Path $shellCopilot)) { New-Item -Path $shellCopilot -Force | Out-Null }
        Set-ItemProperty -Path $shellCopilot -Name 'IsCopilotAvailable' -Value 0 -Type DWord
        Set-ItemProperty -Path $shellCopilot -Name 'CopilotDisabledReason' -Value 'FeatureIsDisabled' -Type String

        $bingChat = "$shellCopilot\BingChat"
        if (-not (Test-Path $bingChat)) { New-Item -Path $bingChat -Force | Out-Null }
        Set-ItemProperty -Path $bingChat -Name 'IsUserEligible' -Value 0 -Type DWord
    }

    $windowsCopilotRuntime = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot'
    if (-not (Test-Path $windowsCopilotRuntime)) { New-Item -Path $windowsCopilotRuntime -Force | Out-Null }
    Set-ItemProperty -Path $windowsCopilotRuntime -Name 'AllowCopilotRuntime' -Value 0 -Type DWord

    $clickToDoPath = 'HKCU:\Software\Microsoft\Windows\Shell\ClickToDo'
    if (-not (Test-Path $clickToDoPath)) { New-Item -Path $clickToDoPath -Force | Out-Null }
    Set-ItemProperty -Path $clickToDoPath -Name 'DisableClickToDo' -Value 1 -Type DWord

    $m365CopilotPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\M365Copilot'
    if (-not (Test-Path $m365CopilotPath)) { New-Item -Path $m365CopilotPath -Force | Out-Null }
    Set-ItemProperty -Path $m365CopilotPath -Name 'AutoStartDelayEnabled' -Value 0 -Type DWord
    Set-ItemProperty -Path $m365CopilotPath -Name 'IsCompanionWindowAvailable' -Value 0 -Type DWord

    foreach ($consentPath in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\generativeAI'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels'
    )) {
        if (-not (Test-Path $consentPath)) { New-Item -Path $consentPath -Force | Out-Null }
        Set-ItemProperty -Path $consentPath -Name 'Value' -Value 'Deny' -Type String
    }

    $appPrivacyPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
    if (-not (Test-Path $appPrivacyPolicy)) { New-Item -Path $appPrivacyPolicy -Force | Out-Null }
    Set-ItemProperty -Path $appPrivacyPolicy -Name 'LetAppsAccessGenerativeAI' -Value 2 -Type DWord
    Set-ItemProperty -Path $appPrivacyPolicy -Name 'LetAppsAccessSystemAIModels' -Value 2 -Type DWord

    $notepadPolicy = 'HKLM:\SOFTWARE\Policies\WindowsNotepad'
    if (-not (Test-Path $notepadPolicy)) { New-Item -Path $notepadPolicy -Force | Out-Null }
    Set-ItemProperty -Path $notepadPolicy -Name 'DisableAIFeatures' -Value 1 -Type DWord

    $paintPolicy = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
    if (-not (Test-Path $paintPolicy)) { New-Item -Path $paintPolicy -Force | Out-Null }
    Set-ItemProperty -Path $paintPolicy -Name 'DisableImageCreator' -Value 1 -Type DWord

    $paintView = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\View'
    if (-not (Test-Path $paintView)) { New-Item -Path $paintView -Force | Out-Null }
    foreach ($entry in @(
        @{ Name = 'IsSignedUpForTargetingService'; Value = 0 }
        @{ Name = 'LeftTargetingService'; Value = 1 }
        @{ Name = 'IsNotInterestedInTargetingService'; Value = 1 }
        @{ Name = 'GettingStartedWelcomePageViewed'; Value = 1 }
        @{ Name = 'GettingStartedStickerGeneratorPageViewed'; Value = 1 }
        @{ Name = 'GettingStartedGenerativeImageEditPageViewed'; Value = 1 }
        @{ Name = 'GettingStartedGenerativeErasePageViewed'; Value = 1 }
        @{ Name = 'GettingStartedGenerativeFillPageViewed'; Value = 1 }
        @{ Name = 'GettingStartedImageCreatorPageViewed'; Value = 1 }
        @{ Name = 'GettingStartedCocreatorPageViewed'; Value = 1 }
    )) {
        Set-ItemProperty -Path $paintView -Name $entry.Name -Value $entry.Value -Type DWord -ErrorAction SilentlyContinue
    }

    $voiceAccessKey = 'HKCU:\Software\Microsoft\VoiceAccess'
    if (-not (Test-Path $voiceAccessKey)) { New-Item -Path $voiceAccessKey -Force | Out-Null }
    Set-ItemProperty -Path $voiceAccessKey -Name 'RunningState' -Value 0 -Type DWord
    Set-ItemProperty -Path $voiceAccessKey -Name 'TextCorrection' -Value 1 -Type DWord

    $gamingAiKey = 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.Xbox.GamingAI.Companion.Host.GamingCompanionHostOptions'
    if (Test-Path -LiteralPath $gamingAiKey) {
        Set-ItemProperty -Path $gamingAiKey -Name 'ActivationType' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamingAiKey -Name 'Server' -Value ' ' -Type String -ErrorAction SilentlyContinue
    }

    $explorerPolicy = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    if (-not (Test-Path $explorerPolicy)) { New-Item -Path $explorerPolicy -Force | Out-Null }
    $existing = Get-ItemProperty -Path $explorerPolicy -Name 'SettingsPageVisibility' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty SettingsPageVisibility
    if ($existing -notlike '*showonly*') {
        if ($existing -and $existing -notlike '*aicomponents;*') {
            $suffix = if ($existing.EndsWith(';')) { 'aicomponents;appactions;' } else { ';aicomponents;appactions;' }
            Set-ItemProperty -Path $explorerPolicy -Name 'SettingsPageVisibility' -Value ($existing + $suffix) -Type String
        } elseif (-not $existing) {
            Set-ItemProperty -Path $explorerPolicy -Name 'SettingsPageVisibility' -Value 'hide:aicomponents;appactions;' -Type String
        }
    }

    $integratedPolicyJson = Join-Path $env:WINDIR 'System32\IntegratedServicesRegionPolicySet.json'
    if (Test-Path $integratedPolicyJson) {
        & takeown.exe /f $integratedPolicyJson *>$null
        & icacls.exe $integratedPolicyJson /grant '*S-1-5-32-544:F' /t *>$null
        try {
            $integratedPolicy = Get-Content $integratedPolicyJson | ConvertFrom-Json
            foreach ($policy in $integratedPolicy.policies) {
                $comment = $policy.'$comment'
                if ($comment -like '*CoPilot*') {
                    $policy.defaultState = 'disabled'
                } elseif ($comment -like '*Manage Recall*') {
                    $policy.defaultState = 'disabled'
                } elseif ($comment -like '*A9*' -or $comment -like '*Settings Agent*') {
                    $policy.defaultState = 'enabled'
                }
            }
            $integratedPolicy | ConvertTo-Json -Depth 100 | Set-Content -Path $integratedPolicyJson -Force
        } catch {
            Write-Warning "IntegratedServicesRegionPolicySet.json update failed: $($_.Exception.Message)"
        }
    }

    $visualAssistJson = Join-Path $env:WINDIR 'SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\VisualAssist\VisualAssistActions.json'
    if (Test-Path $visualAssistJson) {
        & takeown.exe /f $visualAssistJson *>$null
        & icacls.exe $visualAssistJson /grant '*S-1-5-32-544:F' /t *>$null
        try {
            $visualAssist = Get-Content $visualAssistJson | ConvertFrom-Json
            $visualAssist.actions | Add-Member -MemberType NoteProperty -Name usesGenerativeAI -Value $false -Force
            $visualAssist | ConvertTo-Json -Depth 100 | Set-Content -Path $visualAssistJson -Force
        } catch {
            Write-Warning "VisualAssistActions.json update failed: $($_.Exception.Message)"
        }
    }
}

function Disable-WinSetupRecallFeature {
    try {
        $recallState = (Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction Stop).State
        if ($recallState -and $recallState -ne 'DisabledWithPayloadRemoved') {
            $ProgressPreference = 'SilentlyContinue'
            Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -Remove -NoRestart -ErrorAction Stop | Out-Null
        }
    } catch {
        $dismInfo = & dism.exe /Online /Get-FeatureInfo /FeatureName:Recall 2>$null
        if ($LASTEXITCODE -eq 0 -and ($dismInfo -notmatch 'Disabled with Payload Removed')) {
            & dism.exe /Online /Disable-Feature /FeatureName:Recall /Remove /NoRestart /Quiet | Out-Null
        }
    }
}

function Set-WinSetupAIStoreBlockPolicy {
    $removeStorePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages'
    if (-not (Test-Path $removeStorePolicy)) { New-Item -Path $removeStorePolicy -Force | Out-Null }
    Set-ItemProperty -Path $removeStorePolicy -Name 'Enabled' -Value 1 -Type DWord
    $copilotStorePolicy = Join-Path $removeStorePolicy 'Microsoft.Copilot_8wekyb3d8bbwe'
    if (-not (Test-Path $copilotStorePolicy)) { New-Item -Path $copilotStorePolicy -Force | Out-Null }
    Set-ItemProperty -Path $copilotStorePolicy -Name 'RemovePackage' -Value 1 -Type DWord
    Set-ItemProperty -Path $removeStorePolicy -Name 'DynamicRemovalList' -Value @(
        'aimgr_8wekyb3d8bbwe'
        'Microsoft.Edge.GameAssist_8wekyb3d8bbwe'
    ) -Type MultiString
}

function Remove-WinSetupAICBSPackages {
    $cbsPackages = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
    if (-not (Test-Path $cbsPackages)) { return }

    $ProgressPreference = 'SilentlyContinue'
    Get-ChildItem $cbsPackages -ErrorAction SilentlyContinue | ForEach-Object {
        $childName = $_.PSChildName
        if ($childName -notmatch 'AIX|Recall|Copilot|CoreAI') { return }
        $visibility = try {
            Get-ItemPropertyValue -Path $_.PSPath -Name Visibility -ErrorAction Stop
        } catch { $null }
        if ($visibility -ne 2) { return }

        Set-ItemProperty -Path $_.PSPath -Name Visibility -Value 1 -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $_.PSPath -Name DefVis -PropertyType DWord -Value 2 -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path (Join-Path $_.PSPath 'Owners') -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $_.PSPath 'Updates') -Force -ErrorAction SilentlyContinue
        try {
            Remove-WindowsPackage -Online -PackageName $childName -NoRestart -ErrorAction Stop | Out-Null
        } catch {
            & dism.exe /Online /Remove-Package /PackageName:$childName /NoRestart /Quiet | Out-Null
        }
        Get-ChildItem (Join-Path $env:WINDIR 'servicing\Packages') -Filter "*$childName*" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Remove-WinSetupAIAppxPackages {
    $aiPackageNames = @(
        'MicrosoftWindows.Client.AIX'
        'MicrosoftWindows.Client.CoPilot'
        'MicrosoftWindows.Client.CoreAI'
        'Microsoft.Windows.Ai.Copilot.Provider'
        'aimgr'
        'Microsoft.WritingAssistant'
    )
    $aiPackagePatterns = @(
        '*Microsoft.AIFabric.CBS*'
        '*WindowsWorkload.*'
        '*MicrosoftWindows.*.Voiess'
        '*MicrosoftWindows.*.Speion'
        '*MicrosoftWindows.*.Livtop'
        '*MicrosoftWindows.*.InpApp'
        '*MicrosoftWindows.*.Filons'
    )

    foreach ($name in $aiPackageNames) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name -or $_.Name -like "$name*" } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
        Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name -or $_.Name -like "$name*" } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $name -or $_.PackageName -like "$name*" } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
    }

    foreach ($pattern in $aiPackagePatterns) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
        Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
    }

    foreach ($package in @('Microsoft.Copilot', 'Microsoft.Windows.Copilot', 'Microsoft.Edge.GameAssist')) {
        Get-AppxPackage -Name $package -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxPackage -AllUsers -Name $package -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }

    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*Copilot*' -or $_.DisplayName -like '*CoreAI*' -or $_.DisplayName -like '*AIX*' } |
        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
}

function Remove-WinSetupAITasksAndServices {
    Get-ScheduledTask -TaskPath '*WindowsAI*' -ErrorAction SilentlyContinue |
        Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\System32\Tasks\Microsoft\Windows\WindowsAI" -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($aiService in @('MicrosoftCopilotElevationService', 'WSAIFabricSvc', 'AarSvc')) {
        Stop-Service -Name $aiService -Force -ErrorAction SilentlyContinue
        & sc.exe delete $aiService *>$null
    }
}

function Disable-WinSetupPhotosAI {
    $photosSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.Photos_8wekyb3d8bbwe\Settings\settings.dat'
    if (-not (Test-Path -LiteralPath $photosSettings)) { return }

    Get-Process -Name 'Microsoft.Photos', 'Photos', 'Microsoft.Lightbox' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $appSettingsRegPath = 'HKEY_USERS\APP_SETTINGS'
    reg.exe UNLOAD $appSettingsRegPath 2>$null | Out-Null

    $attempts = 0
    do {
        reg.exe LOAD $appSettingsRegPath $photosSettings 2>$null | Out-Null
        $attempts++
    } while ($LASTEXITCODE -ne 0 -and $attempts -lt 30)

    if ($LASTEXITCODE -ne 0) { return }

    try {
        $evokeKey = Get-ChildItem "registry::$appSettingsRegPath" -Recurse -ErrorAction Stop |
            Where-Object { $_.PSChildName -like '*Evoke' } |
            Select-Object -First 1
        if (-not $evokeKey) { return }

        $aiSettings = @(
            'Designer-IsEnabled'
            'EditHVC-GenerativeErase-IsEnabled'
            'EditHVC-Stylizer-IsEnabled'
            'EditHVC-SuperResolution-IsEnabled'
            'EditHVC-BackgroundBlur-IsEnabled'
            'Moodboard-IsEnabled'
            'SDXL-IsEnabled'
            'ViewerCopilotOnContextMenu-IsEnabled'
            'WindowsIndexerSemanticSearchIsEnabledIntel'
            'WindowsIndexerSemanticSearchIsEnabledAMD'
            'WindowsIndexerSemanticSearchIsEnabledQCOM'
        )

        $regContent = "Windows Registry Editor Version 5.00`n"
        $timestampBytes = [BitConverter]::GetBytes([int64](Get-Date).ToFileTime())
        $timestamp = ($timestampBytes | ForEach-Object { '{0:x2}' -f $_ }) -join ','

        foreach ($name in $aiSettings) {
            $regContent += @"
[$($evokeKey.Name)\$name]
"5f5e10b"=hex:00
"Timestamp"=hex(b):$timestamp

"@
        }

        $tempReg = Join-Path $env:TEMP 'WinSetup-PhotosSettings.reg'
        Set-Content -Path $tempReg -Value $regContent -Force -Encoding Unicode
        reg.exe IMPORT $tempReg 2>$null | Out-Null
        Remove-Item $tempReg -Force -ErrorAction SilentlyContinue
    } finally {
        reg.exe UNLOAD $appSettingsRegPath 2>$null | Out-Null
    }
}

function Disable-WinSetupGamingCopilot {
    $overlaySettingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe\LocalState\profileDataSettings.txt'
    if (Test-Path -LiteralPath $overlaySettingsPath) {
        Get-Process -Name '*gamebar*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        try {
            $jsonObj = Get-Content -LiteralPath $overlaySettingsPath -Raw | ConvertFrom-Json
            $companion = $jsonObj.profile.settingsStorage.PSObject.Properties |
                Where-Object { $_.Name -like '*GamingCompanionWidget*' } |
                Select-Object -First 1
            if ($companion) {
                foreach ($prop in $companion.Value.PSObject.Properties) {
                    if ($prop.Name -in @('suppressFirstFavorite', 'suppressFirstLaunch')) {
                        $companion.Value.$($prop.Name) = $true
                    } else {
                        $companion.Value.$($prop.Name) = $false
                    }
                }
                $companion.Value | Add-Member -NotePropertyName 'homeMenuVisibleUser' -NotePropertyValue $false -Force
                $jsonObj | ConvertTo-Json -Depth 10 -Compress | Set-Content -LiteralPath $overlaySettingsPath -Force
            }
        } catch {
            Write-Warning "Gaming Copilot profile update failed: $($_.Exception.Message)"
        }
    }
}

function Remove-WinSetupAIFiles {
    $aiPackageNames = @(
        'MicrosoftWindows.Client.AIX'
        'MicrosoftWindows.Client.CoPilot'
        'Microsoft.Windows.Ai.Copilot.Provider'
        'Microsoft.Copilot'
        'MicrosoftWindows.Client.CoreAI'
        'Microsoft.Edge.GameAssist'
        'aimgr'
        'Microsoft.WritingAssistant'
        'Microsoft.AIFabric.CBS'
        'WindowsWorkload'
        'Voiess'
        'Speion'
        'Livtop'
        'InpApp'
        'Filons'
    )

    $paths = foreach ($root in @(
        Join-Path $env:SystemRoot 'SystemApps'
        Join-Path ${env:ProgramFiles} 'WindowsApps'
        Join-Path $env:ProgramData 'Microsoft\Windows\AppRepository'
        Join-Path $env:SystemRoot 'SystemApps\SxS'
    )) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -Directory -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                foreach ($name in $aiPackageNames) {
                    if ($_.FullName -like "*$name*") { $_.FullName; break }
                }
            }
    }

    foreach ($servicingRoot in @(
        Join-Path $env:SystemRoot 'servicing\Packages'
        Join-Path $env:SystemRoot 'System32\CatRoot'
    )) {
        if (-not (Test-Path $servicingRoot)) { continue }
        $paths += Get-ChildItem -Path $servicingRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -like '*UserExperience-AIX*' -or
                $_.FullName -like '*Copilot*' -or
                $_.FullName -like '*UserExperience-Recall*' -or
                $_.FullName -like '*CoreAI*'
            } |
            ForEach-Object { $_.FullName }
    }

    foreach ($extra in @(
        Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\ActionsMcpHost.exe'
        Join-Path $env:SystemRoot 'System32\config\systemprofile\AppData\Local\Microsoft\WindowsApps\ActionsMcpHost.exe'
        Join-Path $env:SystemRoot 'System32\voiceaccess.exe'
    )) {
        if (Test-Path -LiteralPath $extra) { $paths += $extra }
    }

    foreach ($path in @($paths | Select-Object -Unique)) {
        Remove-WinSetupLockedPath -Path $path
    }

    foreach ($dll in @(
        Join-Path $env:SystemRoot 'System32\Windows.AI.MachineLearning.dll'
        Join-Path $env:SystemRoot 'SysWOW64\Windows.AI.MachineLearning.dll'
        Join-Path $env:SystemRoot 'System32\Windows.AI.MachineLearning.Preview.dll'
        Join-Path $env:SystemRoot 'SysWOW64\Windows.AI.MachineLearning.Preview.dll'
        Join-Path $env:SystemRoot 'System32\SettingsHandlers_Copilot.dll'
        Join-Path $env:SystemRoot 'System32\SettingsHandlers_A9.dll'
    )) {
        Remove-WinSetupLockedPath -Path $dll
    }

    Remove-Item -Path "$env:LOCALAPPDATA\CoreAIPlatform*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Accessibility\VoiceAccess.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:USERPROFILE\.copilot" -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($uri in @('ms-office-ai', 'ms-copilot', 'ms-clicktodo')) {
        Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\$uri" -Recurse -Force -ErrorAction SilentlyContinue
    }

    $captureRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture'
    if (Test-Path $captureRoot) {
        Get-ChildItem -Path $captureRoot -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -eq 'FxProperties' } |
            ForEach-Object {
                $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($props.PSObject.Properties.Name -contains '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5') {
                    Set-ItemProperty -Path $_.PSPath -Name '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5' -Value 1 -Type DWord
                }
            }
    }
}

function Invoke-WinSetupAIRemoval {
    Write-Host '[*] AI policies, Recall, and store blocks...' -ForegroundColor DarkGray
    Set-WinSetupAIPolicies
    Disable-WinSetupRecallFeature
    Set-WinSetupAIStoreBlockPolicy

    Write-Host '[*] Removing Copilot and AI packages...' -ForegroundColor DarkGray
    Remove-WinSetupAIAppxPackages
    Remove-WinSetupAICBSPackages
    Remove-WinSetupAITasksAndServices
    Invoke-WinSetupWingetUninstall --id Microsoft.Copilot_8wekyb3d8bbwe --silent --accept-source-agreements --disable-interactivity
    Invoke-WinSetupWingetUninstall --name "Microsoft Copilot" --silent --accept-source-agreements --disable-interactivity

    Write-Host '[*] Disabling Photos AI and Gaming Copilot...' -ForegroundColor DarkGray
    Disable-WinSetupGamingCopilot
    Disable-WinSetupPhotosAI
    Remove-WinSetupAIFiles
}

function Install-WinSetupAIPreventionPackage {
    $existing = Get-WindowsPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.PackageName -like '*zoicware*' }
    if ($existing -and $existing.PackageState -ne 'InstallPending') { return }

    $arm = ((Get-CimInstance -Class Win32_ComputerSystem).SystemType -match 'ARM64') -or
        ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
    $arch = if ($arm) { 'arm64' } else { 'amd64' }

    $certPath = 'HKLM:\Software\Microsoft\SystemCertificates\ROOT\Certificates\8A334AA8052DD244A647306A76B8178FA215F344'
    if (-not (Test-Path $certPath)) { New-Item -Path $certPath -Force | Out-Null }

    $cabPath = Join-Path $env:TEMP "ZoicwareRemoveWindowsAI-$arch.cab"
    $cabUrl = "https://github.com/zoicware/RemoveWindowsAI/raw/refs/heads/main/RemoveWindowsAIPackage/$arch/ZoicwareRemoveWindowsAI-$($arch)1.0.0.0.cab"

    try {
        Invoke-WebRequest -Uri $cabUrl -OutFile $cabPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Warning "Could not download AI prevention package: $($_.Exception.Message)"
        return
    }

    try {
        Add-WindowsPackage -Online -PackagePath $cabPath -NoRestart -IgnoreCheck -ErrorAction Stop | Out-Null
    } catch {
        & dism.exe /Online /Add-Package "/PackagePath:$cabPath" /NoRestart /IgnoreCheck 2>$null | Out-Null
    }

    Remove-Item -LiteralPath $cabPath -Force -ErrorAction SilentlyContinue
}

function Register-WinSetupAIUpdateCleanupTask {
    param([string]$SourceScript = $PSCommandPath)

    if (-not $SourceScript -or -not (Test-Path -LiteralPath $SourceScript)) {
        Write-Warning 'WinSetup-AI-UpdateCleanup.ps1 source not found — skipping scheduled task.'
        return
    }

    $destDir = Join-Path $env:ProgramData 'WinSetup'
    if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
    Copy-Item -LiteralPath $SourceScript -Destination (Join-Path $destDir 'WinSetup-AI-UpdateCleanup.ps1') -Force

    $helpersSource = Join-Path (Split-Path -Parent $SourceScript) 'WinSetup-WingetHelpers.ps1'
    if (Test-Path -LiteralPath $helpersSource) {
        Copy-Item -LiteralPath $helpersSource -Destination (Join-Path $destDir 'WinSetup-WingetHelpers.ps1') -Force
    }

    Set-WinSetupCachedBuild

    $destScript = Join-Path $destDir 'WinSetup-AI-UpdateCleanup.ps1'
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$destScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'WinSetup-AIUpdateCleanup' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

function Initialize-WinSetupAI {
    Invoke-WinSetupAIRemoval
    Write-Host '[*] AI prevention package...' -ForegroundColor DarkGray
    Install-WinSetupAIPreventionPackage
    Write-Host '[*] AI update cleanup task...' -ForegroundColor DarkGray
    Register-WinSetupAIUpdateCleanupTask
}

if ($MyInvocation.InvocationName -ne '.' -and $PSCommandPath) {
    if (Test-WinSetupOSBuildChanged) {
        Invoke-WinSetupAIRemoval
        Install-WinSetupAIPreventionPackage
        Set-WinSetupCachedBuild
    }
}
