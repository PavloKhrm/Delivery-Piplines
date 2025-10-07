@echo off
setlocal enableextensions

echo Multi-Tenant Kubernetes Blog Template System - Complete Local Setup
echo ==================================================================

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click the .bat and choose "Run as administrator".
    pause
    exit /b 1
)

set "ROOT=%~dp0"

echo This will configure local domains with self-signed SSL certificates.
echo All blogs will be accessible via HTTPS with local domain names.
echo.

REM Run the complete setup
echo Running complete local domain setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%fix-local-domains.ps1"

echo.
echo Updating Windows hosts file...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%update-hosts-file.ps1"

echo.
echo Setting up port forwarding...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%fix-port-forwarding.ps1"

echo.
echo ========================================
echo LOCAL DOMAIN SETUP COMPLETE!
echo ========================================
echo.
echo Your blogs are now configured for local access with self-signed SSL.
echo.
echo Next steps:
echo 1. Check the summary files in .\logs\ directory
echo 2. Access your blogs via HTTPS (browser will show SSL warning - click Advanced -> Proceed)
echo 3. Start the dashboard: Tools\quick-start-dashboard.bat
echo.
pause
