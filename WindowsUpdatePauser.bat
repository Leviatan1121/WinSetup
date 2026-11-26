@echo off
setlocal enabledelayedexpansion
set "ScriptName=PauseWindowsUpdates.bat"
set "FilePathCurrentUser=%appdata%\Microsoft\Windows\Start Menu\Programs\Startup\%ScriptName%"
set "FilePathAllUsers=%programdata%\Microsoft\Windows\Start Menu\Programs\Startup\%ScriptName%"

if "%~1"=="ALLUSERS" (
    CALL :CREATE_FILE
    move "%ScriptName%" "%FilePathAllUsers%"
    exit /b 0
)

:MENU
    cls
    echo =========================================
    echo  Windows Update Pauser - by Leviatan1121
    echo =========================================
    if exist "%FilePathCurrentUser%" (
        echo  1. Disable for current user
    ) else (
        echo  1. Enable for current user
    )
    if exist "%FilePathAllUsers%" (
        echo  2. Disable for all users
    ) else (
        echo  2. Enable for all users
    )
    echo  3. Resume updates
    echo  4. Pause updates for ...
    echo  0. Exit
    echo =========================================
    set /p option="Select an option (0-4): "

    if "%option%"=="1" goto CURRENT_USER
    if "%option%"=="2" goto ALL_USERS
    if "%option%"=="3" (
        echo:
        goto RESUME_UPDATES
    )
    if "%option%"=="4" goto PAUSE_UPDATES
    if "%option%"=="0" exit
    echo: & echo Invalid option, returning to menu... & timeout /t 1 > nul
goto MENU


:CURRENT_USER
    echo:
    if exist "%FilePathCurrentUser%" (
        del "%FilePathCurrentUser%"
        echo Disabled for current user.
        if not exist "%FilePathAllUsers%" (
            goto RESUME_UPDATES
        )
    ) else (
        CALL :CREATE_FILE
        move "%ScriptName%" "%FilePathCurrentUser%"
        start "" cmd /c "%FilePathCurrentUser%"
    )
    echo: & echo Returning to menu... & timeout /t 2 > nul
goto MENU


:ALL_USERS
    echo:
    if exist "%FilePathAllUsers%" (
        del "%FilePathAllUsers%"
        if exist "%FilePathCurrentUser%" (
            del "%FilePathCurrentUser%"
        )
        echo Disabled for all users.
        goto RESUME_UPDATES
    ) else (
        echo Accept the next window...
        (echo Set oShell = CreateObject("Shell.Application"^)) > "%temp%\enable_all_users.vbs"
        (echo oShell.ShellExecute "%~f0", "ALLUSERS", "", "runas", 1) >> "%temp%\enable_all_users.vbs"
        cscript //nologo "%temp%\enable_all_users.vbs"
        timeout /t 1 /nobreak >nul
        del "%temp%\enable_all_users.vbs" 2>nul
        if exist "%FilePathAllUsers%" (
            start "" cmd /c "%FilePathAllUsers%"
            echo: & echo Returning to menu... & timeout /t 2 > nul
        ) else (
            echo Cancelled or failed. & echo:
            pause
        )
    )
goto MENU


:RESUME_UPDATES
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesStartTime' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesExpiryTime' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesStartTime' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesEndTime' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesStartTime' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesEndTime' -ErrorAction SilentlyContinue;"
    if %ERRORLEVEL% equ 0 (
        echo Updates resumed successfully.
    ) else (
        echo Error resuming updates.
    )
    echo: & echo Returning to menu... & timeout /t 2 > nul
goto MENU


:PAUSE_UPDATES
    cls
    echo =========================================
    echo           Pause updates for ...
    echo =========================================
    echo  1. Weeks
    echo  2. Months
    echo  3. Years
    echo  0. Return to menu
    echo =========================================
    set /p option="Select an option (0-3): "

    echo:
    if "%option%"=="1" (
        echo Enter how many weeks or 0 to cancel.
        set /p Weeks="Weeks: "
        set /a days=7*!Weeks!
        if !days! gtr 0 (
            goto DO_PAUSE
        ) else (
            echo:
        )
    )
    if "%option%"=="2" (
        echo Enter how many months or 0 to cancel.
        set /p Months="Months: "
        set /a days=30*!Months!
        if !days! gtr 0 (
            goto DO_PAUSE
        ) else (
            echo:
        )
    )
    if "%option%"=="3" (
        echo Enter how many years or 0 to cancel.
        set /p Years="Years: "
        set /a days=365*!Years!
        if !days! gtr 0 (
            goto DO_PAUSE
        ) else (
            echo:
        )
    )
    if "%option%"=="0" goto MENU
    echo Invalid option, returning to menu... & timeout /t 1 > nul
goto PAUSE_UPDATES


:DO_PAUSE
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$pause=(Get-Date).AddDays(!days!).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); $start=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesExpiryTime' -Value $pause; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesEndTime' -Value $pause; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesEndTime' -Value $pause;"
    if !ERRORLEVEL! equ 0 (
        echo: & echo Updates paused for !days! days.
        echo: & echo Returning to menu... & timeout /t 2 > nul
        goto MENU
    ) else (
        echo: & echo Error pausing updates. & echo:
        pause
    )
goto PAUSE_UPDATES


:CREATE_FILE
    (
    echo @echo off
    echo PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$pause=(Get-Date).AddDays(7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); $start=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseUpdatesExpiryTime' -Value $pause; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseFeatureUpdatesEndTime' -Value $pause; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesStartTime' -Value $start; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'PauseQualityUpdatesEndTime' -Value $pause;"
    echo if %%ERRORLEVEL%% equ 0 ^(
    echo    color 0A
    echo    echo Windows Update paused for 7 days.
    echo    timeout /t 2 ^> nul
    echo ^) else ^(
    echo    color 4
    echo    echo Error pausing Windows Update. ^& echo:
    echo    pause
    echo ^)
    ) > "%ScriptName%"