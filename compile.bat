@echo off

set gcc=mingw64\bin\gcc.exe
set exe=WinSetup.exe
set output=out\%exe%

if exist %output% (
    tasklist | find %exe% >nul 2>&1
    if not errorlevel 1 (
        echo Stopping %exe%...
        taskkill /IM %exe% /F >nul 2>&1
        echo Done. & echo:
    )
    echo Deleting %exe%...
    del %output%
    echo Done. & echo:
)

echo Compiling %exe%...
if not exist out mkdir out
%gcc% -o %output% src\main.c src\functions.c -mwindows

if exist %output% (
    echo Done. & echo:
    echo Starting %exe%...
    start %output%
    echo Done.
)
echo:
exit /b