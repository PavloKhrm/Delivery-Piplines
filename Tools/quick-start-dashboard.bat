@echo off
setlocal enableextensions

echo Multi-Tenant Kubernetes Blog Template System - Quick Dashboard Start
echo ====================================================================

REM Check if we're in the right directory
if not exist "Dashboard\command-runner.js" (
    echo ERROR: Dashboard\command-runner.js not found.
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

REM Check if port forwarding is active
echo Checking port forwarding status...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Job | Where-Object { $_.Name -like '*traefik*' } | Select-Object Name, State"

REM Start the dashboard
echo Starting dashboard server...
cd Dashboard
start /B node command-runner.js

REM Wait a moment for the server to start
timeout /t 3 /nobreak >nul

REM Open the dashboard in browser
echo Opening dashboard in browser...
start http://localhost:3001/multi-blog-dashboard.html

echo.
echo Dashboard should now be running at: http://localhost:3001/multi-blog-dashboard.html
echo.
echo To stop the dashboard: Press Ctrl+C in the dashboard window
echo To stop port forwarding: Run Tools\stop-port-forwarding.ps1
echo.
pause
