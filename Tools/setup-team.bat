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
echo ================================================================
echo OPTIONAL: Advanced Pod Deployments
echo ================================================================
echo.
echo After the main setup, you can optionally deploy:
echo.
echo 1. Dashboard as Kubernetes Pod (Persistent Dashboard)
echo    - Survives PC restarts
echo    - Runs as Kubernetes pod
echo    - Access via LoadBalancer/NodePort
echo.
echo 2. Persistent Port Forwarder (Auto Port Forwarding)
echo    - Automatically forwards Traefik and Dashboard ports
echo    - Runs as Kubernetes pods with multiple replicas
echo    - Survives PC restarts and network issues
echo.
echo To deploy these optional components:
echo   .\create-dashboard-pod.bat          - Deploy dashboard as pod
echo   .\create-persistent-port-forwarder.bat - Deploy auto port forwarding
echo.
echo These are separate from the main setup and can be deployed anytime.
echo.

set /p deploy_optional="Deploy optional pod components now? (y/n): "
if /i "%deploy_optional%"=="y" (
    echo.
    echo Deploying Dashboard as Kubernetes Pod...
    call "create-dashboard-pod.bat"
    
    echo.
    echo Deploying Persistent Port Forwarder...
    call "create-persistent-port-forwarder.bat"
    
    echo.
    echo Optional pod deployments completed!
) else (
    echo.
    echo Skipping optional pod deployments.
    echo You can deploy them later using:
    echo   .\create-dashboard-pod.bat
    echo   .\create-persistent-port-forwarder.bat
)

echo.
echo ================================================================
echo Setup complete! Press any key to exit...
echo ================================================================
pause >nul
