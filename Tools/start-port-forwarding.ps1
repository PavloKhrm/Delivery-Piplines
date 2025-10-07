# Start Port Forwarding for Local Domain Access
# This script starts kubectl port forwarding for Traefik services

param(
    [switch]$EnableLogging = $false
)

Write-Host "Starting Port Forwarding for Local Domain Access" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    
    if ($EnableLogging) {
        $logFile = ".\logs\port-forwarding-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Checking for existing port forwarding processes..." "INFO" "Cyan"

# Stop any existing kubectl port-forward processes
try {
    $existingProcesses = Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*" }
    if ($existingProcesses) {
        foreach ($process in $existingProcesses) {
            Write-Log "Stopping existing port forwarding process (PID: $($process.Id))" "INFO" "Yellow"
            Stop-Process -Id $process.Id -Force
        }
        Start-Sleep -Seconds 2
    }
    Write-Log "Existing port forwarding processes stopped" "SUCCESS" "Green"
} catch {
    Write-Log "No existing port forwarding processes found" "INFO" "Yellow"
}

Write-Log "Starting new port forwarding for Traefik..." "INFO" "Cyan"

# Check if Traefik service exists
try {
    $traefikService = kubectl get service traefik -n traefik-system -o json | ConvertFrom-Json
    if ($traefikService) {
        Write-Log "Traefik service found in traefik-system namespace" "SUCCESS" "Green"
    } else {
        throw "Traefik service not found"
    }
} catch {
    Write-Log "Traefik service not found in traefik-system namespace" "ERROR" "Red"
    Write-Log "Please ensure Traefik is properly installed" "WARNING" "Yellow"
    exit 1
}

# Start port forwarding for Traefik
try {
    Write-Log "Starting port forwarding: 8080->80 (HTTP) and 8443->443 (HTTPS)" "INFO" "Cyan"
    
    # Create a PowerShell script to run port forwarding in background
    $portForwardScript = @"
# Port Forwarding Script for Traefik
Write-Host "Starting Traefik port forwarding..." -ForegroundColor Green
Write-Host "HTTP:  http://localhost:8080" -ForegroundColor Cyan
Write-Host "HTTPS: https://localhost:8443" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Yellow

kubectl port-forward -n traefik-system service/traefik 8080:80 8443:443
"@
    
    $scriptPath = ".\Tools\port-forward-traefik.ps1"
    $portForwardScript | Out-File -FilePath $scriptPath -Encoding UTF8
    
    # Start port forwarding in a new window
    Start-Process -FilePath "powershell" -ArgumentList "-NoExit", "-File", $scriptPath
    
    Start-Sleep -Seconds 3
    
    Write-Log "Port forwarding started successfully" "SUCCESS" "Green"
    Write-Log "HTTP access: http://localhost:8080" "INFO" "Cyan"
    Write-Log "HTTPS access: https://localhost:8443" "INFO" "Cyan"
    Write-Log "`nLocal domains should now be accessible:" "INFO" "Yellow"
    
    # Get domains from Kubernetes
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
            if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                $host = $ingresses.items[0].spec.rules[0].host
                Write-Log "  https://$host:8443/" "INFO" "White"
            }
        } catch {
            # Skip failed namespaces
        }
    }
    
} catch {
    Write-Log "Failed to start port forwarding: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

Write-Log "`nPort forwarding setup complete!" "SUCCESS" "Green"
Write-Log "A new PowerShell window opened with port forwarding running" "INFO" "Cyan"
Write-Log "Close that window to stop port forwarding" "INFO" "Yellow"
