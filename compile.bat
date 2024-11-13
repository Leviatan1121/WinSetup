@echo off

set gcc=mingw64\bin\gcc.exe
set output=out\WinSetup.exe

if exist %output% (
    tasklist | find "WinSetup.exe" >nul 2>&1
    if not errorlevel 1 (
        echo Stopping WinSetup...
        taskkill /IM "WinSetup.exe" /F >nul 2>&1
        echo Done. & echo:
    )
    echo Deleting WinSetup...
    del %output%
    echo Done. & echo:
)

echo Compiling WinSetup...
if not exist out mkdir out
%gcc% -o %output% src\main.c src\functions.c -mwindows

if exist %output% (
    echo Done. & echo:
    echo Starting WinSetup...
    start %output%
    echo Done.
)
echo:
exit /b