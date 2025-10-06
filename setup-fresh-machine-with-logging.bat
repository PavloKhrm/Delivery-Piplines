@echo off
setlocal enableextensions

echo Multi-Tenant Kubernetes Blog Template System - Setup with Logging
echo =================================================================
echo.
echo This will run the setup script with comprehensive logging enabled.
echo All output and errors will be saved to a log file in the .\logs\ directory.
echo.

REM Run the PowerShell script with logging enabled
powershell -NoProfile -ExecutionPolicy Bypass -File "setup-fresh-machine.ps1" -EnableLogging

echo.
echo Setup completed. Check the .\logs\ directory for detailed logs.
pause
