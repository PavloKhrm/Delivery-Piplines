@echo off
REM Install prerequisites using Chocolatey
REM This handles the installation of all required tools for the team

echo Multi-Tenant Kubernetes Blog Template System - Prerequisites Installation
echo ==========================================================================

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo.
echo Installing Chocolatey package manager...
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"

echo.
echo Installing required tools...
choco install docker-desktop kubernetes-cli kind kubernetes-helm nodejs npm git -y

echo.
echo Prerequisites installation complete!
echo Please restart your computer or at least restart PowerShell/Command Prompt
echo Then run setup-team.bat to continue with the setup
echo.
pause
