@echo off
setlocal
REM ============================================================================
REM Purpose:
REM   Launch the paired PowerShell script reliably, no matter where this CMD is
REM   started from (double-click, shortcut, Explorer, or another shell).
REM
REM Key variable:
REM   %%~dp0 = drive + path of this CMD file (with trailing backslash), e.g.
REM            C:\Some Folder\
REM   Using %%~dp0 avoids dependence on the current working directory.
REM
REM If the PowerShell filename changes:
REM   Update SCRIPT_NAME below only. Leave the rest of the file unchanged.
REM ============================================================================

set "SCRIPT_NAME=TrackSessions.Simulator CR1.PreReserve.2026-09-07.mod1.ps1"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%%SCRIPT_NAME%"

REM Check if the script exists
if not exist "%SCRIPT_PATH%" (
    echo PowerShell script not found at "%SCRIPT_PATH%".
    pause
    exit /b 1
)

REM Remove Mark-of-the-Web if present so policy prompts/blocking are less likely.
REM This is equivalent to running: Unblock-File -LiteralPath <script>
REM Errors are suppressed to keep launch resilient on systems where this is not needed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Unblock-File -LiteralPath '%SCRIPT_PATH%' -ErrorAction Stop } catch { }" >nul 2>&1

REM Run the PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%

