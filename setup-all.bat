@echo off
setlocal enableextensions

REM Ensure Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo This script must be run as Administrator.
  echo Right-click the .bat and choose "Run as administrator".
  pause
  exit /b 1
)

REM Ensure Chocolatey
where choco >nul 2>&1
if %errorlevel% neq 0 (
  echo Installing Chocolatey...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol=[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
  if %errorlevel% neq 0 (
    echo Failed to install Chocolatey.
    exit /b 1
  )
  set "PATH=%ALLUSERSPROFILE%\chocolatey\bin;%PATH%"
)

REM Update Chocolatey and enable global confirmation
choco feature enable -n allowGlobalConfirmation >nul 2>&1
choco upgrade chocolatey -y

REM Install prerequisites
choco install docker-desktop -y
choco install kubernetes-cli -y
choco install kind -y
choco install kubernetes-helm -y
choco install nodejs-lts -y
choco install git -y

REM Optional: refresh env for current session (best to open new shell after)
setx PATH "%PATH%" >nul 2>&1

REM Run setup script (project bootstrap)
set "ROOT=%~dp0"
echo Running setup-fresh-machine.ps1 with logging enabled...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%setup-fresh-machine.ps1" -EnableLogging
if %errorlevel% neq 0 (
  echo setup-fresh-machine.ps1 failed. Check .\logs\ directory for detailed error logs.
  exit /b 1
)

REM Run complete setup fix
if exist "%ROOT%Tools\fix-complete-setup.ps1" (
    echo Running Tools\fix-complete-setup.ps1...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Tools\fix-complete-setup.ps1"
)

REM Run port forwarding fix
if exist "%ROOT%Tools\fix-port-forwarding.ps1" (
    echo Running Tools\fix-port-forwarding.ps1...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Tools\fix-port-forwarding.ps1"
)

REM Run migrate-to-new-machine (optional helper)
if exist "%ROOT%Tools\migrate-to-new-machine.ps1" (
  echo Running Tools\migrate-to-new-machine.ps1...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Tools\migrate-to-new-machine.ps1"
)

echo All done. You can now start the dashboard:
echo   cd Dashboard ^&^& node command-runner.js
echo Or run: powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location -Path .\Dashboard; node .\command-runner.js"
pause
