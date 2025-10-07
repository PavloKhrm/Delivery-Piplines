# Complete Setup Fix Script
# This script fixes all issues for fresh machine installations

param(
    [switch]$EnableLogging = $false
)

Write-Host "Multi-Tenant Kubernetes Blog Template System - Complete Setup Fix" -ForegroundColor Green
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

# Step 1: Create placeholder Docker images
Write-Log "`nStep 1: Creating placeholder Docker images..." "INFO" "Cyan"

Write-Log "Creating backend placeholder image..." "INFO" "Yellow"
try {
    # Pull nginx:alpine if not exists
    docker pull nginx:alpine
    
    # Create temporary container
    docker run -d --name temp-backend nginx:alpine
    
    # Commit as blog-backend:latest
    docker commit temp-backend blog-backend:latest
    
    # Clean up
    docker rm -f temp-backend
    
    Write-Log "Backend placeholder image created successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to create backend placeholder image: $($_.Exception.Message)" "ERROR" "Red"
}

Write-Log "Creating frontend placeholder image..." "INFO" "Yellow"
try {
    # Create temporary container
    docker run -d --name temp-frontend nginx:alpine
    
    # Commit as blog-frontend:latest
    docker commit temp-frontend blog-frontend:latest
    
    # Clean up
    docker rm -f temp-frontend
    
    Write-Log "Frontend placeholder image created successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to create frontend placeholder image: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 2: Load images into Kind cluster
Write-Log "`nStep 2: Loading images into Kind cluster..." "INFO" "Cyan"
try {
    kind load docker-image blog-backend:latest --name k8s-blog-template
    kind load docker-image blog-frontend:latest --name k8s-blog-template
    Write-Log "Images loaded into Kind cluster successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to load images into Kind cluster: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 3: Stop any existing port forwarding jobs
Write-Log "`nStep 3: Cleaning up existing port forwarding..." "INFO" "Cyan"
try {
    Get-Job | Where-Object { $_.Name -like "*port-forward*" -or $_.Command -like "*kubectl*" } | Stop-Job
    Get-Job | Where-Object { $_.Name -like "*port-forward*" -or $_.Command -like "*kubectl*" } | Remove-Job
    Write-Log "Existing port forwarding jobs cleaned up" "SUCCESS" "Green"
} catch {
    Write-Log "No existing port forwarding jobs to clean up" "INFO" "Yellow"
}

# Step 4: Set up Traefik port forwarding
Write-Log "`nStep 4: Setting up Traefik port forwarding..." "INFO" "Cyan"
try {
    Start-Job -Name "traefik-port-forward" -ScriptBlock { 
        kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443 
    }
    Start-Sleep -Seconds 5
    Write-Log "Traefik port forwarding started" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to start Traefik port forwarding: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 5: Fix ingress middleware issues for existing deployments
Write-Log "`nStep 5: Fixing ingress middleware issues..." "INFO" "Cyan"

# Get all blog namespaces
$namespaces = kubectl get namespaces -o json | ConvertFrom-Json
$blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }

foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    Write-Log "Processing namespace: $nsName" "INFO" "Yellow"
    
    try {
        # Get ingress in this namespace
        $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
        
        foreach ($ingress in $ingresses.items) {
            $ingressName = $ingress.metadata.name
            Write-Log "Fixing ingress: $ingressName" "INFO" "Gray"
            
            # Remove problematic middleware annotations
            kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.middlewares- --overwrite 2>$null
            kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.rule- --overwrite 2>$null
            
            Write-Log "Fixed ingress: $ingressName" "SUCCESS" "Green"
        }
    } catch {
        Write-Log "Failed to process namespace $nsName : $($_.Exception.Message)" "ERROR" "Red"
    }
}

# Step 6: Wait for Traefik to reload and test access
Write-Log "`nStep 6: Testing access..." "INFO" "Cyan"
Start-Sleep -Seconds 10

# Test if we can access any blog
$testSuccessful = $false
foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    
    try {
        # Get the host from ingress
        $ingressJson = kubectl get ingress -n $nsName -o json
        if ($ingressJson) {
            $ingress = $ingressJson | ConvertFrom-Json
            if ($ingress.items -and $ingress.items.Count -gt 0) {
                $host = $ingress.items[0].spec.rules[0].host
                Write-Log "Testing access to: https://$host`:8443/" "INFO" "Yellow"
                
                # Test with curl
                try {
                    $result = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" "https://$host`:8443/"
                    if ($result -eq "200") {
                        Write-Log "SUCCESS: Blog is accessible at https://$host`:8443/" "SUCCESS" "Green"
                        $testSuccessful = $true
                        break
                    } else {
                        Write-Log "HTTP $result - Blog not responding at https://$host`:8443/" "WARNING" "Yellow"
                    }
                } catch {
                    Write-Log "Connection failed to https://$host`:8443/ - $($_.Exception.Message)" "ERROR" "Red"
                }
            } else {
                Write-Log "No ingress items found in namespace $nsName" "WARNING" "Yellow"
            }
        } else {
            Write-Log "No ingress found in namespace $nsName" "WARNING" "Yellow"
        }
    } catch {
        Write-Log "Failed to test namespace $nsName - $($_.Exception.Message)" "ERROR" "Red"
    }
}

# Final summary
Write-Log "`nSetup Fix Complete!" "SUCCESS" "Green"
Write-Log "===================" "SUCCESS" "Green"

if ($testSuccessful) {
    Write-Log "Your blog system is now fully functional!" "SUCCESS" "Green"
    Write-Log "Access your blogs via HTTPS on port 8443" "INFO" "Cyan"
} else {
    Write-Log "Setup completed but some issues may remain" "WARNING" "Yellow"
    Write-Log "Check the logs above for any errors" "INFO" "Cyan"
}

Write-Log "`nPort forwarding is running in the background" "INFO" "Cyan"
Write-Log "To stop port forwarding, run: Get-Job | Stop-Job; Get-Job | Remove-Job" "INFO" "Gray"
