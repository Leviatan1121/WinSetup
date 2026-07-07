#region Dark Theme
Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
Start-Sleep -Seconds 3
Get-Process -Name "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force
#endregion

#region Disable Transparency Effects
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0
#endregion

#region Disable Animation Effects (Accessibility > Visual effects)
$desktopPath = 'HKCU:\Control Panel\Desktop'
$metricsPath = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$mask = (Get-ItemProperty -Path $desktopPath).UserPreferencesMask.Clone()
$mask[0] = $mask[0] -band (-bnot 0x0E)
$mask[1] = $mask[1] -band (-bnot 0x0C)
$mask[4] = $mask[4] -band (-bnot 0x02)
Set-ItemProperty -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value $mask
Set-ItemProperty -Path $metricsPath -Name 'MinAnimate' -Value '0'
#endregion

#region Enable End Task (End Task in Taskbar)
$TaskbarDevPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
if (-not (Test-Path $TaskbarDevPath)) { New-Item -Path $TaskbarDevPath -Force | Out-Null }
Set-ItemProperty -Path $TaskbarDevPath -Name "TaskbarEndTask" -Value 1 -Type DWord
#endregion

#region Multi Task: No show browser tabs in Alt + Tab
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3
#endregion

#region File Explorer: show file extensions and hidden items
$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -Value 0 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "Hidden" -Value 1 -Type DWord
Set-ItemProperty -Path $ExplorerPath -Name "ShowSuperHidden" -Value 1 -Type DWord
#endregion

#region Taskbar: hide search box
$SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarModeCache" -Value 1 -Type DWord
#endregion

#region Restart Explorer to apply changes
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process explorer.exe
#endregion