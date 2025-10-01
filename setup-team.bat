@echo off
REM Multi-Tenant Kubernetes Blog Template System - Team Setup
REM This batch file handles PowerShell execution policy issues for team members

echo Multi-Tenant Kubernetes Blog Template System - Team Setup
echo ================================================================

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not available or not working properly
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

echo.
echo Setting up PowerShell execution policy for current user...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

echo.
echo Running the main setup script...
powershell -ExecutionPolicy Bypass -File "setup-fresh-machine.ps1"

echo.
echo Setup complete! Press any key to exit...
pause >nul
