@echo off
REM Start the Multi-Tenant Kubernetes Blog System
REM This script handles all the setup and starts the system

echo Multi-Tenant Kubernetes Blog System - Starting...
echo ================================================

REM Check if we're in the right directory
if not exist "command-runner.js" (
    echo ERROR: command-runner.js not found
    echo Please run this script from the project root directory
    pause
    exit /b 1
)

REM Set PowerShell execution policy for current session
echo Setting up PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" >nul 2>&1

REM Check if Docker is running
echo Checking Docker status...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running
    echo Please start Docker Desktop and try again
    pause
    exit /b 1
)

REM Check if Kind cluster exists
echo Checking Kubernetes cluster...
kind get clusters | findstr "k8s-blog-template" >nul 2>&1
if %errorlevel% neq 0 (
    echo Kubernetes cluster not found. Running setup...
    powershell -ExecutionPolicy Bypass -File "setup-fresh-machine.ps1"
    if %errorlevel% neq 0 (
        echo Setup failed. Please check the error messages above.
        pause
        exit /b 1
    )
)

REM Start the dashboard
echo Starting dashboard server...
echo Dashboard will be available at: http://localhost:3001/multi-blog-dashboard.html
echo Press Ctrl+C to stop the dashboard
echo.

node command-runner.js
