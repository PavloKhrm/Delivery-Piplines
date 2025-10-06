@echo off
echo Starting all blog services...
powershell -ExecutionPolicy Bypass -File "start-all-services.ps1"
pause
