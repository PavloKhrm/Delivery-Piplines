# Fix Port Forwarding Issues
# This script handles port conflicts and sets up proper port forwarding

param(
    [switch]$EnableLogging = $false
)

Write-Host "Multi-Tenant Kubernetes Blog Template System - Port Forwarding Fix" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Step 1: Kill existing port forwarding processes
Write-Log "`nStep 1: Cleaning up existing port forwarding..." "INFO" "Cyan"

try {
    # Kill any existing kubectl port-forward processes
    Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Kill any processes using ports 8080 and 8443
    $ports = @(8080, 8443)
    foreach ($port in $ports) {
        $processes = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($pid in $processes) {
            try {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Write-Log "Killed process $pid using port $port" "INFO" "Yellow"
            } catch {
                Write-Log "Could not kill process $pid using port $port" "WARNING" "Yellow"
            }
        }
    }
    
    Write-Log "Existing port forwarding processes cleaned up" "SUCCESS" "Green"
} catch {
    Write-Log "Error cleaning up processes: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 2: Wait for ports to be released
Write-Log "`nStep 2: Waiting for ports to be released..." "INFO" "Cyan"
Start-Sleep -Seconds 5

# Step 3: Set up Traefik port forwarding with alternative ports
Write-Log "`nStep 3: Setting up Traefik port forwarding..." "INFO" "Cyan"

# Try different port combinations
$portCombinations = @(
    @{HTTP=8080; HTTPS=8443},
    @{HTTP=8081; HTTPS=8444},
    @{HTTP=8082; HTTPS=8445},
    @{HTTP=8083; HTTPS=8446}
)

$successfulPorts = $null
foreach ($combo in $portCombinations) {
    $httpPort = $combo.HTTP
    $httpsPort = $combo.HTTPS
    
    Write-Log "Trying ports HTTP:$httpPort HTTPS:$httpsPort" "INFO" "Yellow"
    
    try {
        # Test if ports are available
        $httpTest = Test-NetConnection -ComputerName localhost -Port $httpPort -InformationLevel Quiet -WarningAction SilentlyContinue
        $httpsTest = Test-NetConnection -ComputerName localhost -Port $httpsPort -InformationLevel Quiet -WarningAction SilentlyContinue
        
        if (-not $httpTest -and -not $httpsTest) {
            # Start port forwarding in background
            $job = Start-Job -Name "traefik-port-forward" -ScriptBlock { 
                param($httpPort, $httpsPort)
                kubectl port-forward -n traefik-system service/traefik "${httpPort}:8080" "${httpsPort}:443"
            } -ArgumentList $httpPort, $httpsPort
            
            Start-Sleep -Seconds 3
            
            # Test if the job is running and ports are working
            $jobStatus = Get-Job -Name "traefik-port-forward" -ErrorAction SilentlyContinue
            if ($jobStatus -and $jobStatus.State -eq "Running") {
                $successfulPorts = $combo
                Write-Log "SUCCESS: Port forwarding active on HTTP:$httpPort HTTPS:$httpsPort" "SUCCESS" "Green"
                break
            } else {
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -ErrorAction SilentlyContinue
            }
        } else {
            Write-Log "Ports $httpPort or $httpsPort are in use, trying next combination" "WARNING" "Yellow"
        }
    } catch {
        Write-Log "Failed to test ports $httpPort/$httpsPort: $($_.Exception.Message)" "ERROR" "Red"
    }
}

if (-not $successfulPorts) {
    Write-Log "Failed to find available ports for Traefik forwarding" "ERROR" "Red"
    Write-Log "Please manually kill processes using ports 8080-8083 and 8443-8446" "WARNING" "Yellow"
    exit 1
}

# Step 4: Update ingress configurations to use working ports
Write-Log "`nStep 4: Testing blog access..." "INFO" "Cyan"

$httpPort = $successfulPorts.HTTP
$httpsPort = $successfulPorts.HTTPS

# Get all blog namespaces
$namespaces = kubectl get namespaces -o json | ConvertFrom-Json
$blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }

$workingBlogs = @()
foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    
    try {
        # Get the host from ingress
        $ingressJson = kubectl get ingress -n $nsName -o json
        if ($ingressJson) {
            $ingress = $ingressJson | ConvertFrom-Json
            if ($ingress.items -and $ingress.items.Count -gt 0) {
                $hostName = $ingress.items[0].spec.rules[0].host
                Write-Log "Testing access to: https://$hostName`:$httpsPort/" "INFO" "Yellow"
                
                # Test with curl
                try {
                    $result = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" "https://$hostName`:$httpsPort/"
                    if ($result -eq "200") {
                        Write-Log "SUCCESS: Blog is accessible at https://$hostName`:$httpsPort/" "SUCCESS" "Green"
                        $workingBlogs += @{
                            Name = $nsName
                            Domain = $hostName
                            HTTPS = $httpsPort
                            HTTP = $httpPort
                        }
                    } else {
                        Write-Log "HTTP $result - Blog not responding at https://$hostName`:$httpsPort/" "WARNING" "Yellow"
                    }
                } catch {
                    Write-Log "Connection failed to https://$hostName`:$httpsPort/ - $($_.Exception.Message)" "ERROR" "Red"
                }
            }
        }
    } catch {
        Write-Log "Failed to test namespace $nsName - $($_.Exception.Message)" "ERROR" "Red"
    }
}

# Step 5: Create a summary file with working URLs
Write-Log "`nStep 5: Creating access summary..." "INFO" "Cyan"

$summaryFile = ".\logs\working-blogs-summary.txt"
$summary = @"
Multi-Tenant Blog System - Working URLs
=======================================
Generated: $(Get-Date)

Port Forwarding Active:
- HTTP: localhost:$httpPort
- HTTPS: localhost:$httpsPort

Working Blogs:
"@

foreach ($blog in $workingBlogs) {
    $summary += "`n- $($blog.Name):"
    $summary += "`n  HTTPS: https://$($blog.Domain):$httpsPort/"
    $summary += "`n  HTTP:  http://$($blog.Domain):$httpPort/"
}

$summary += "`n`nNote: Add these domains to your hosts file (C:\Windows\System32\drivers\etc\hosts):"
foreach ($blog in $workingBlogs) {
    $summary += "`n127.0.0.1 $($blog.Domain)"
}

try {
    if (!(Test-Path ".\logs")) {
        New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
    }
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Log "Access summary saved to: $summaryFile" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to save summary: $($_.Exception.Message)" "ERROR" "Red"
}

# Final summary
Write-Log "`nPort Forwarding Fix Complete!" "SUCCESS" "Green"
Write-Log "===============================" "SUCCESS" "Green"

if ($workingBlogs.Count -gt 0) {
    Write-Log "`nWorking blogs:" "INFO" "Cyan"
    foreach ($blog in $workingBlogs) {
        Write-Log "• https://$($blog.Domain):$httpsPort/" "SUCCESS" "Green"
    }
} else {
    Write-Log "No working blogs found. Check the logs above for issues." "WARNING" "Yellow"
}

Write-Log "`nPort forwarding is running in the background" "INFO" "Cyan"
Write-Log "To stop port forwarding, run: Get-Job | Stop-Job; Get-Job | Remove-Job" "INFO" "Gray"
Write-Log "`nSummary saved to: $summaryFile" "INFO" "Cyan"
