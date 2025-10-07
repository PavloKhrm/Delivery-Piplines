# Wildcard Local Domain Fix for Multi-Tenant Kubernetes Blog Template System
# Uses *.emit-it.local wildcard domain to avoid port conflicts and simplify setup

param(
    [switch]$EnableLogging = $false
)

Write-Host "Multi-Tenant Kubernetes Blog Template System - Wildcard Domain Fix" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Green

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
        $logFile = ".\logs\wildcard-domains-fix-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Starting wildcard domain fix..." "INFO" "Cyan"

# Step 1: Stop any existing port forwarding processes
Write-Log "`nStep 1: Stopping existing port forwarding processes..." "INFO" "Cyan"
try {
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Log "Existing port forwarding processes stopped" "SUCCESS" "Green"
} catch {
    Write-Log "No existing port forwarding processes found" "INFO" "Yellow"
}

# Step 2: Check if Traefik is running
Write-Log "`nStep 2: Checking Traefik configuration..." "INFO" "Cyan"
try {
    $traefikPod = kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o json | ConvertFrom-Json
    if ($traefikPod.items.Count -eq 0) {
        throw "Traefik pod not found"
    }
    
    $podName = $traefikPod.items[0].metadata.name
    Write-Log "Traefik pod found: $podName" "SUCCESS" "Green"
    
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

# Step 5: Generate wildcard SSL certificate
Write-Log "`nStep 5: Generating wildcard SSL certificate..." "INFO" "Cyan"
$certsDir = "ssl-certificates"
if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Path $certsDir -Force | Out-Null
}

# Wildcard domain for local development
$wildcardDomain = "*.emit-it.local"
$baseDomain = "emit-it.local"

try {
    # Generate wildcard certificate
    & mkcert -cert-file "$certsDir\wildcard-emit-it-cert.pem" -key-file "$certsDir\wildcard-emit-it-key.pem" $wildcardDomain $baseDomain
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Wildcard SSL certificate generated successfully for $wildcardDomain" "SUCCESS" "Green"
    } else {
        throw "mkcert failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Log "Failed to generate wildcard SSL certificate: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

# Step 6: Create Kubernetes SSL secret
Write-Log "`nStep 6: Creating Kubernetes wildcard SSL secret..." "INFO" "Cyan"
try {
    kubectl create secret tls wildcard-emit-it-ssl-cert --cert="$certsDir\wildcard-emit-it-cert.pem" --key="$certsDir\wildcard-emit-it-key.pem" -n traefik-system --dry-run=client -o yaml | kubectl apply -f -
    Write-Log "Kubernetes wildcard SSL secret created successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to create Kubernetes wildcard SSL secret: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 7: Get or create wildcard domains dynamically
Write-Log "`nStep 7: Setting up wildcard domains..." "INFO" "Cyan"
$domains = @()

# Get existing blog namespaces and convert them to wildcard domains
try {
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    if ($blogNamespaces.Count -gt 0) {
        Write-Log "Found $($blogNamespaces.Count) existing blog namespaces" "INFO" "Yellow"
        
        foreach ($namespace in $blogNamespaces) {
            $nsName = $namespace.metadata.name
            # Convert namespace name to subdomain (e.g., blog-meow-tech-dev -> meow-tech)
            $subdomain = $nsName -replace "^blog-", "" -replace "-dev$", ""
            $wildcardDomainName = "$subdomain.emit-it.local"
            $domains += $wildcardDomainName
            Write-Log "Created wildcard domain: $wildcardDomainName for namespace $nsName" "INFO" "Yellow"
        }
    } else {
        Write-Log "No existing blog namespaces found - creating default wildcard domains" "INFO" "Yellow"
        # Create default wildcard domains for fresh setup
        $defaultSubdomains = @("demo", "tech", "admin", "api")
        foreach ($subdomain in $defaultSubdomains) {
            $wildcardDomainName = "$subdomain.emit-it.local"
            $domains += $wildcardDomainName
            Write-Log "Created default wildcard domain: $wildcardDomainName" "INFO" "Yellow"
        }
    }
    
    Write-Log "Total wildcard domains configured: $($domains.Count)" "SUCCESS" "Green"
    foreach ($domain in $domains) {
        Write-Log "  - $domain" "INFO" "White"
    }
    
} catch {
    Write-Log "Failed to get namespaces: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

# Step 8: Update existing ingress resources to use wildcard domains
Write-Log "`nStep 8: Updating ingress resources to use wildcard domains..." "INFO" "Cyan"
if ($blogNamespaces.Count -gt 0) {
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
            if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                foreach ($ingress in $ingresses.items) {
                    $ingressName = $ingress.metadata.name
                    
                    # Convert namespace to subdomain
                    $subdomain = $nsName -replace "^blog-", "" -replace "-dev$", ""
                    $newDomain = "$subdomain.emit-it.local"
                    
                    Write-Log "Updating ingress '$ingressName' in namespace '$nsName' to use domain '$newDomain'" "INFO" "Yellow"
                    
                    # Create patch file for ingress update
                    $patchContent = @"
spec:
  rules:
  - host: $newDomain
    http:
      paths:
      - backend:
          service:
            name: $subdomain-frontend
            port:
              number: 80
        path: /
        pathType: Prefix
      - backend:
          service:
            name: $subdomain-backend
            port:
              number: 3000
        path: /api
        pathType: Prefix
      - backend:
          service:
            name: $subdomain-backend
            port:
              number: 3000
        path: /health
        pathType: Prefix
  tls:
  - hosts:
    - $newDomain
    secretName: wildcard-emit-it-tls
"@
                    
                    $patchFile = "temp-$ingressName-patch.yaml"
                    $patchContent | Out-File -FilePath $patchFile -Encoding UTF8
                    
                    # Apply the patch
                    kubectl patch ingress $ingressName -n $nsName --patch-file $patchFile
                    
                    # Clean up patch file
                    Remove-Item $patchFile -ErrorAction SilentlyContinue
                    
                    Write-Log "Ingress '$ingressName' updated successfully" "SUCCESS" "Green"
                }
            }
        } catch {
            Write-Log "Failed to update ingress for namespace ${nsName}: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
} else {
    Write-Log "No existing ingresses to update" "INFO" "Yellow"
}

# Step 9: Create TLS secrets for each namespace using wildcard certificate
Write-Log "`nStep 9: Creating TLS secrets for each namespace..." "INFO" "Cyan"
if ($blogNamespaces.Count -gt 0) {
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            Write-Log "Creating wildcard TLS secret for namespace '$nsName'" "INFO" "Yellow"
            
            # Create TLS secret using wildcard certificate
            kubectl create secret tls wildcard-emit-it-tls --cert="$certsDir\wildcard-emit-it-cert.pem" --key="$certsDir\wildcard-emit-it-key.pem" -n $nsName --dry-run=client -o yaml | kubectl apply -f -
            
            Write-Log "Wildcard TLS secret created for namespace '$nsName'" "SUCCESS" "Green"
        } catch {
            Write-Log "Failed to create TLS secret for namespace ${nsName}: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
} else {
    Write-Log "No existing namespaces to create TLS secrets for" "INFO" "Yellow"
}

# Step 10: Update Traefik configuration for wildcard domains
Write-Log "`nStep 10: Updating Traefik configuration..." "INFO" "Cyan"
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
        address: ":80"
        http:
          redirections:
            entrypoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
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

# Step 11: Restart Traefik to apply new configuration
Write-Log "`nStep 11: Restarting Traefik..." "INFO" "Cyan"
try {
    kubectl rollout restart deployment/traefik -n traefik-system
    kubectl rollout status deployment/traefik -n traefik-system --timeout=120s
    Write-Log "Traefik restarted successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to restart Traefik: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 12: Update hosts file with wildcard domains
Write-Log "`nStep 12: Updating Windows hosts file..." "INFO" "Cyan"
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
        
        # Add wildcard domain entries
        $newEntries = @()
        $newEntries += "127.0.0.1 emit-it.local"
        foreach ($domain in $domains) {
            $newEntries += "127.0.0.1 $domain"
        }
        
        $updatedHosts = $filteredHosts + "" + "# Wildcard blog domains (auto-generated by wildcard-domains-fix.ps1)" + $newEntries
        $updatedHosts | Out-File -FilePath $hostsFile -Encoding ASCII
        
        Write-Log "Hosts file updated successfully" "SUCCESS" "Green"
        foreach ($entry in $newEntries) {
            Write-Log "Added: $entry" "INFO" "White"
        }
    } catch {
        Write-Log "Failed to update hosts file: $($_.Exception.Message)" "ERROR" "Red"
    }
} else {
    Write-Log "Not running as Administrator. Please manually add these entries to hosts file:" "WARNING" "Yellow"
    Write-Log "127.0.0.1 emit-it.local" "INFO" "White"
    foreach ($domain in $domains) {
        Write-Log "127.0.0.1 $domain" "INFO" "White"
    }
}

# Step 13: Start port forwarding with standard ports
Write-Log "`nStep 13: Starting port forwarding..." "INFO" "Cyan"
try {
    # Stop any existing port forwarding first
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Use standard ports
    $httpPort = 8080
    $httpsPort = 8443
    
    Start-Process -FilePath "kubectl" -ArgumentList "port-forward", "-n", "traefik-system", "service/traefik", "$httpPort`:80", "$httpsPort`:443" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Log "Port forwarding started: $httpPort->80 (HTTP) and $httpsPort->443 (HTTPS)" "SUCCESS" "Green"
    
    # Save port information for other scripts
    $portInfo = @{
        httpPort = $httpPort
        httpsPort = $httpsPort
        timestamp = Get-Date
    }
    $portInfo | ConvertTo-Json | Out-File -FilePath ".\port-forward-info.json" -Encoding UTF8
    
} catch {
    Write-Log "Failed to start port forwarding: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 14: Create summary report
Write-Log "`nStep 14: Creating summary report..." "INFO" "Cyan"
$summaryFile = ".\logs\wildcard-domains-fix-summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$summary = @"
Wildcard Domain Fix Summary
===========================
Generated: $(Get-Date)

Setup Type: $(if ($blogNamespaces.Count -gt 0) { 'Existing Deployment' } else { 'Fresh Setup' })
Wildcard Domain: *.emit-it.local
Base Domain: emit-it.local

Issues Fixed:
- Wildcard SSL certificate generated for *.emit-it.local
- TLS secrets created for all namespaces using wildcard certificate
- Traefik configuration updated for wildcard domains
- Hosts file updated with wildcard domain entries
- Port forwarding configured with dynamic port selection to avoid conflicts

Configured Domains:
"@

foreach ($domain in $domains) {
    $summary += "`n- $domain"
    $summary += "`n  HTTP:  http://$domain`:8080/"
    $summary += "`n  HTTPS: https://$domain`:8443/"
}

$summary += "`n`nAccess URLs:"
foreach ($domain in $domains) {
    $summary += "`n- Frontend: https://$domain`:8443/"
    $summary += "`n- Backend API: https://$domain`:8443/api/"
    $summary += "`n- Health Check: https://$domain`:8443/health"
}

$summary += "`n`nNotes:"
$summary += "`n- All domains use wildcard SSL certificate (*.emit-it.local)"
$summary += "`n- Browser will show SSL warning (click 'Advanced' -> 'Proceed')"
$summary += "`n- Port forwarding uses standard ports (8080 for HTTP, 8443 for HTTPS)"
$summary += "`n- Wildcard certificate is valid for all subdomains of emit-it.local"
$summary += "`n- Script handles both fresh setups and existing deployments"
$summary += "`n- Port information saved to port-forward-info.json"

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
Write-Log "`nWildcard Domain Fix Complete!" "SUCCESS" "Green"
Write-Log "===============================" "SUCCESS" "Green"
Write-Log "`nSetup Type: $(if ($blogNamespaces.Count -gt 0) { 'Existing Deployment' } else { 'Fresh Setup' })" "INFO" "Cyan"
Write-Log "Wildcard domains configured: $($domains.Count)" "INFO" "Cyan"
Write-Log "`nAccess your blogs at:" "INFO" "Yellow"
foreach ($domain in $domains) {
    Write-Log "  https://$domain`:8443/" "INFO" "White"
}

Write-Log "`nSummary report saved to: $summaryFile" "INFO" "Cyan"
Write-Log "`nPort forwarding is running in the background" "INFO" "Cyan"
Write-Log "Port information saved to: port-forward-info.json" "INFO" "Cyan"
Write-Log "If you need to stop port forwarding, run: Get-Process kubectl | Stop-Process" "INFO" "Gray"
