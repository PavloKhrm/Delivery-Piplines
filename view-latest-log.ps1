# View Latest Setup Log
# This script helps you view the most recent setup log file

param(
    [Parameter(Mandatory = $false)]
    [switch]$OpenInEditor = $false
)

$logDir = ".\logs"
if (!(Test-Path $logDir)) {
    Write-Host "No logs directory found. Run setup with logging enabled first." -ForegroundColor Red
    exit 1
}

# Get the most recent log file
$latestLog = Get-ChildItem -Path $logDir -Filter "setup-fresh-machine-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (!$latestLog) {
    Write-Host "No setup log files found in .\logs\ directory." -ForegroundColor Red
    exit 1
}

Write-Host "Latest log file: $($latestLog.FullName)" -ForegroundColor Cyan
Write-Host "File size: $([math]::Round($latestLog.Length / 1KB, 2)) KB" -ForegroundColor Cyan
Write-Host "Last modified: $($latestLog.LastWriteTime)" -ForegroundColor Cyan
Write-Host ""

if ($OpenInEditor) {
    # Try to open in default text editor
    Start-Process notepad.exe -ArgumentList $latestLog.FullName
    Write-Host "Opened log file in Notepad." -ForegroundColor Green
} else {
    # Display the last 50 lines of the log
    Write-Host "Last 50 lines of the log:" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow
    Get-Content $latestLog.FullName -Tail 50
    Write-Host ""
    Write-Host "To view the full log, run: .\view-latest-log.ps1 -OpenInEditor" -ForegroundColor Cyan
}
