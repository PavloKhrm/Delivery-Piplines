# Stop All Port Forwarding
# This script stops all background port forwarding jobs

Write-Host "Stopping all port forwarding jobs..." -ForegroundColor Yellow

try {
    # Stop all PowerShell background jobs
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    
    # Kill any remaining kubectl port-forward processes
    Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Where-Object { 
        $_.CommandLine -like "*port-forward*" 
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "All port forwarding stopped successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error stopping port forwarding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nCurrent jobs status:" -ForegroundColor Cyan
Get-Job
