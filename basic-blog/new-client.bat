@echo off
powershell -ExecutionPolicy Bypass -File ".\k8s\new-client.ps1" -ClientId %1