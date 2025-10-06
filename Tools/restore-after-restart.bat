@echo off
REM Restore Multi-Tenant Blog System After PC Restart
REM This batch file handles everything needed after a PC restart

echo Restoring Multi-Tenant Blog System After PC Restart
echo ===================================================

REM Check if we're in the right directory
if not exist "restore-after-restart.ps1" (
    echo ERROR: restore-after-restart.ps1 not found
    echo Please run this script from the project root directory
    pause
    exit /b 1
)

REM Set PowerShell execution policy for current session
echo Setting up PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" >nul 2>&1

REM Run the PowerShell script
echo Running system restoration...
powershell -ExecutionPolicy Bypass -File "restore-after-restart.ps1"

echo.
echo System restoration completed!
echo.
echo Your multi-blog system is now fully restored after PC restart:
echo.
echo Access Points:
echo - Dashboard: http://localhost:3001/multi-blog-dashboard.html
echo - Traefik: http://localhost:8080
echo.
echo All port forwarding has been automatically restored.
echo Dashboard server is running and all services are accessible.
echo.
pause

