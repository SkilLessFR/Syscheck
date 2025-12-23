@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM CEL SysCheck Launcher - PowerShell 5.1 with OCR Support
REM ============================================================================
REM This launcher ensures:
REM 1. Script runs with Administrator privileges
REM 2. Uses PowerShell 5.1 (built into Windows) for OCR functionality
REM 3. Launches SysCheck.ps1
REM ============================================================================

REM Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ========================================
echo CEL SysCheck Launcher
echo Running as Administrator
echo ========================================
echo.

echo [*] Launching SysCheck with PowerShell 5.1 (for OCR support)...
echo.

REM IMPORTANT: Use powershell.exe (5.1), NOT pwsh.exe (7+)
REM PowerShell 5.1 has native WinRT support for Windows 11 OCR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0syscheckv5.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] SysCheck encountered an error (Exit code: %errorlevel%)
    echo.
    pause
)

exit /b %errorlevel%
