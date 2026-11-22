@echo off
REM Power Automate Failed Runs Inspector Launcher
REM This batch file provides an easy way to launch the application

setlocal enabledelayedexpansion

echo.
echo ====================================
echo Power Automate Failed Runs Inspector
echo ====================================
echo.
echo This will launch the PowerShell application.
echo.
echo.
echo Select launch mode:
echo [1] Simulation Mode (uses sample data, no connection required)
echo [2] Live Mode (connects to Power Automate)
echo [3] Exit
echo.

set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" (
    echo.
    echo Launching in Simulation Mode...
    echo.
    powershell -NoExit -Command "cd '%~dp0'; .\WpfPowerAutomateFailedRuns.ps1 -Mode Simulation"
) else if "%choice%"=="2" (
    echo.
    echo Launching in Live Mode...
    echo.
    powershell -NoExit -Command "cd '%~dp0'; .\WpfPowerAutomateFailedRuns.ps1 -Mode Live"
) else if "%choice%"=="3" (
    echo Exiting...
    exit /b 0
) else (
    echo.
    echo Invalid choice. Please run again and select 1, 2, or 3.
    pause
    exit /b 1
)
