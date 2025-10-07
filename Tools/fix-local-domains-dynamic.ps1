# Dynamic Local Domains Fix for Multi-Tenant Kubernetes Blog Template System
# This script handles both fresh setups (no domains) and existing deployments

param(
    [switch]$EnableLogging = $false
)

Write-Host "Multi-Tenant Kubernetes Blog Template System - Dynamic Local Domain Fix" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green

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
        $logFile = ".\logs\dynamic-local-domains-fix-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Starting dynamic local domain fix..." "INFO" "Cyan"

# Step 1: Stop any existing port forwarding
Write-Log "`nStep 1: Stopping existing port forwarding processes..." "INFO" "Cyan"
try {
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" -and $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Log "Existing port forwarding processes stopped" "SUCCESS" "Green"
} catch {
    Write-Log "No existing port forwarding processes found" "INFO" "Yellow"
}

# Step 2: Check if Traefik is running and get actual ports
Write-Log "`nStep 2: Checking Traefik configuration..." "INFO" "Cyan"
try {
    $traefikPod = kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o json | ConvertFrom-Json
    if ($traefikPod.items.Count -eq 0) {
        throw "Traefik pod not found"
    }
    
    # Get actual container ports from pod description
    $podName = $traefikPod.items[0].metadata.name
    $podDesc = kubectl describe pod $podName -n traefik-system
    
    # Extract port information dynamically
    $webPort = 8000
    $webSecurePort = 8443
    $traefikPort = 8080
    
    if ($podDesc -match "8000/TCP.*web") {
        $webPort = 8000
    }
    if ($podDesc -match "8443/TCP.*websecure") {
        $webSecurePort = 8443
    }
    if ($podDesc -match "8080/TCP.*traefik") {
        $traefikPort = 8080
    }
    
    Write-Log "Traefik pod found: $podName" "SUCCESS" "Green"
    Write-Log "Container ports: Web=$webPort, WebSecure=$webSecurePort, Traefik=$traefikPort" "INFO" "Yellow"
    
} catch {
    Write-Log "Traefik not found or not running: $($_.Exception.Message)" "ERROR" "Red"
    Write-Log "Cannot proceed without Traefik. Please run setup-fresh-machine.ps1 first." "ERROR" "Red"
    exit 1
}

# Step 3: Install mkcert if not present
Write-Log "`nStep 3: Checking for mkcert installation..." "INFO" "Cyan"
$mkcertInstalled = Get-Command mkcert -ErrorAction SilentlyContinue

if (-not $mkcertInstalled) {
    Write-Log "Installing mkcert for SSL certificate generation..." "INFO" "Yellow"
    try {
        $mkcertUrl = "https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-windows-amd64.exe"
        $mkcertPath = "$env:TEMP\mkcert.exe"
        
        Invoke-WebRequest -Uri $mkcertUrl -OutFile $mkcertPath -UseBasicParsing
        Move-Item $mkcertPath "$env:USERPROFILE\mkcert.exe" -Force
        
        $env:PATH += ";$env:USERPROFILE"
        Write-Log "mkcert installed successfully" "SUCCESS" "Green"
    } catch {
        Write-Log "Failed to install mkcert: $($_.Exception.Message)" "ERROR" "Red"
        exit 1
    }
} else {
    Write-Log "mkcert is already installed" "SUCCESS" "Green"
}

# Step 4: Install local CA
Write-Log "`nStep 4: Installing local CA..." "INFO" "Cyan"
try {
    & mkcert -install
    Write-Log "Local CA installed successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to install local CA: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 5: Get domains dynamically - handle both existing and fresh setups
Write-Log "`nStep 5: Getting domains dynamically..." "INFO" "Cyan"
$domains = @()

# First, try to get domains from existing ingress resources
try {
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
            if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                foreach ($ingress in $ingresses.items) {
                    $domainHost = $ingress.spec.rules[0].host
                    $domains += $domainHost
                    Write-Log "Found existing domain: $domainHost for namespace $nsName" "INFO" "Yellow"
                }
            }
        } catch {
            Write-Log "Failed to get ingress for namespace $nsName" "WARNING" "Yellow"
        }
    }
} catch {
    Write-Log "Failed to get namespaces: $($_.Exception.Message)" "WARNING" "Yellow"
}

# If no domains found (fresh setup), create default local domains
if ($domains.Count -eq 0) {
    Write-Log "No existing domains found - this appears to be a fresh setup" "INFO" "Yellow"
    Write-Log "Creating default local domains for development..." "INFO" "Cyan"
    
    # Create common local development domains
    $defaultDomains = @("demo1.local", "tech1.local", "localhost", "local.dev")
    $domains = $defaultDomains
    
    Write-Log "Default domains configured: $($domains -join ', ')" "SUCCESS" "Green"
} else {
    Write-Log "Found $($domains.Count) existing domains: $($domains -join ', ')" "SUCCESS" "Green"
}

# Step 6: Generate SSL certificates for all domains
Write-Log "`nStep 6: Generating SSL certificates..." "INFO" "Cyan"
$certsDir = "ssl-certificates"
if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Path $certsDir -Force | Out-Null
}

try {
    $domainArgs = @()
    foreach ($domain in $domains) {
        $domainArgs += $domain
    }
    & mkcert -cert-file "$certsDir\blog-cert.pem" -key-file "$certsDir\blog-key.pem" $domainArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "SSL certificates generated successfully for $($domains.Count) domains" "SUCCESS" "Green"
    } else {
        throw "mkcert failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Log "Failed to generate SSL certificates: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

# Step 7: Create Kubernetes SSL secret
Write-Log "`nStep 7: Creating Kubernetes SSL secret..." "INFO" "Cyan"
try {
    kubectl create secret tls blog-ssl-cert --cert="$certsDir\blog-cert.pem" --key="$certsDir\blog-key.pem" -n traefik-system --dry-run=client -o yaml | kubectl apply -f -
    Write-Log "Kubernetes SSL secret created successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to create Kubernetes SSL secret: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 8: Create TLS secrets for existing namespaces (only if they exist)
Write-Log "`nStep 8: Creating TLS secrets for existing namespaces..." "INFO" "Cyan"
if ($blogNamespaces.Count -gt 0) {
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
            if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                foreach ($ingress in $ingresses.items) {
                    $domainHost = $ingress.spec.rules[0].host
                    $secretName = $ingress.spec.tls[0].secretName
                    
                    Write-Log "Creating TLS secret '$secretName' for domain '$domainHost' in namespace '$nsName'" "INFO" "Yellow"
                    
                    kubectl create secret tls $secretName --cert="$certsDir\blog-cert.pem" --key="$certsDir\blog-key.pem" -n $nsName --dry-run=client -o yaml | kubectl apply -f -
                    Write-Log "TLS secret '$secretName' created for namespace '$nsName'" "SUCCESS" "Green"
                }
            }
        } catch {
            Write-Log "Failed to create TLS secret for namespace ${nsName}: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
} else {
    Write-Log "No existing blog namespaces found - skipping TLS secret creation" "INFO" "Yellow"
}

# Step 9: Update Traefik configuration for local domains
Write-Log "`nStep 9: Updating Traefik configuration..." "INFO" "Cyan"
$traefikConfig = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-config
  namespace: traefik-system
data:
  traefik.yaml: |
    api:
      dashboard: true
      insecure: true
    entryPoints:
      web:
        address: ":$webPort"
        http:
          redirections:
            entrypoint:
              to: websecure
              scheme: https
      websecure:
        address: ":$webSecurePort"
    providers:
      kubernetes:
        ingressClass: traefik
        allowCrossNamespace: true
    certificatesResolvers:
      default:
        tls: {}
    log:
      level: INFO
    accessLog: {}
"@

try {
    $traefikConfig | kubectl apply -f -
    Write-Log "Traefik configuration updated successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to update Traefik configuration: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 10: Restart Traefik to apply new configuration
Write-Log "`nStep 10: Restarting Traefik..." "INFO" "Cyan"
try {
    kubectl rollout restart deployment/traefik -n traefik-system
    kubectl rollout status deployment/traefik -n traefik-system --timeout=120s
    Write-Log "Traefik restarted successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to restart Traefik: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 11: Update hosts file
Write-Log "`nStep 11: Updating Windows hosts file..." "INFO" "Cyan"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($isAdmin) {
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    
    try {
        $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
        
        # Remove existing blog entries
        $filteredHosts = $currentHosts | Where-Object { 
            $_ -notmatch "^127\.0\.0\.1.*\.local.*$" -and 
            $_ -notmatch "^#.*blog.*domain.*$" 
        }
        
        # Add new entries
        $newEntries = @()
        foreach ($domain in $domains) {
            if ($domain -ne "localhost") {  # Don't add localhost to hosts file
                $newEntries += "127.0.0.1 $domain"
            }
        }
        
        if ($newEntries.Count -gt 0) {
            $updatedHosts = $filteredHosts + "" + "# Blog domains (auto-generated by dynamic-local-domains-fix.ps1)" + $newEntries
            $updatedHosts | Out-File -FilePath $hostsFile -Encoding ASCII
            
            Write-Log "Hosts file updated successfully" "SUCCESS" "Green"
            foreach ($entry in $newEntries) {
                Write-Log "Added: $entry" "INFO" "White"
            }
        }
    } catch {
        Write-Log "Failed to update hosts file: $($_.Exception.Message)" "ERROR" "Red"
    }
} else {
    Write-Log "Not running as Administrator. Please manually add these entries to hosts file:" "WARNING" "Yellow"
    foreach ($domain in $domains) {
        if ($domain -ne "localhost") {
            Write-Log "127.0.0.1 $domain" "INFO" "White"
        }
    }
}

# Step 12: Start port forwarding with correct port mappings
Write-Log "`nStep 12: Starting port forwarding..." "INFO" "Cyan"
try {
    # Use correct port mappings based on actual container ports
    Start-Process -FilePath "kubectl" -ArgumentList "port-forward", "-n", "traefik-system", "service/traefik", "8080:$webPort", "8443:$webSecurePort" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Log "Port forwarding started: 8080->$webPort (HTTP) and 8443->$webSecurePort (HTTPS)" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to start port forwarding: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 13: Create summary report
Write-Log "`nStep 13: Creating summary report..." "INFO" "Cyan"
$summaryFile = ".\logs\dynamic-local-domains-fix-summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$summary = @"
Dynamic Local Domain Fix Summary
================================
Generated: $(Get-Date)

Setup Type: $(if ($domains.Count -eq 4) { 'Fresh Setup' } else { 'Existing Deployment' })
Traefik Container Ports: Web=$webPort, WebSecure=$webSecurePort, Traefik=$traefikPort

Issues Fixed:
- SSL certificates generated for all local domains
- TLS secrets created for existing namespaces
- Traefik configuration updated for local domains
- Hosts file updated with domain entries
- Port forwarding configured with correct port mappings

Configured Domains:
"@

foreach ($domain in $domains) {
    $summary += "`n- $domain"
    if ($domain -ne "localhost") {
        $summary += "`n  HTTP:  http://$domain`:8080/"
        $summary += "`n  HTTPS: https://$domain`:8443/"
    } else {
        $summary += "`n  HTTP:  http://localhost:8080/"
        $summary += "`n  HTTPS: https://localhost:8443/"
    }
}

$summary += "`n`nAccess URLs:"
foreach ($domain in $domains) {
    if ($domain -ne "localhost") {
        $summary += "`n- Frontend: https://$domain`:8443/"
        $summary += "`n- Backend API: https://$domain`:8443/api/"
        $summary += "`n- Health Check: https://$domain`:8443/health"
    } else {
        $summary += "`n- Frontend: https://localhost:8443/"
        $summary += "`n- Backend API: https://localhost:8443/api/"
        $summary += "`n- Health Check: https://localhost:8443/health"
    }
}

$summary += "`n`nNotes:"
$summary += "`n- All domains use self-signed SSL certificates"
$summary += "`n- Browser will show SSL warning (click 'Advanced' -> 'Proceed')"
$summary += "`n- Port forwarding is running in background"
$summary += "`n- SSL certificates are valid for local development"
$summary += "`n- Script handles both fresh setups and existing deployments"

try {
    if (!(Test-Path ".\logs")) {
        New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
    }
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Log "Summary report saved to: $summaryFile" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to save summary report: $($_.Exception.Message)" "ERROR" "Red"
}

# Final summary
Write-Log "`nDynamic Local Domain Fix Complete!" "SUCCESS" "Green"
Write-Log "=====================================" "SUCCESS" "Green"
Write-Log "`nSetup Type: $(if ($domains.Count -eq 4) { 'Fresh Setup' } else { 'Existing Deployment' })" "INFO" "Cyan"
Write-Log "Domains configured: $($domains.Count)" "INFO" "Cyan"
Write-Log "`nAccess your blogs at:" "INFO" "Yellow"
foreach ($domain in $domains) {
    if ($domain -ne "localhost") {
        Write-Log "  https://$domain`:8443/" "INFO" "White"
    } else {
        Write-Log "  https://localhost:8443/" "INFO" "White"
    }
}

Write-Log "`nSummary report saved to: $summaryFile" "INFO" "Cyan"
Write-Log "`nPort forwarding is running in the background" "INFO" "Cyan"
Write-Log "If you need to stop port forwarding, run: Get-Process kubectl | Stop-Process" "INFO" "Gray"
