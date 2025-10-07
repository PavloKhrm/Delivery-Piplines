# Fix Local Domains with Self-Signed SSL
# This script configures local domains with self-signed certificates for Traefik

param(
    [switch]$EnableLogging = $false
)

Write-Host "Multi-Tenant Kubernetes Blog Template System - Local Domain SSL Fix" -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "`nConfiguring local domains with self-signed SSL certificates..." "INFO" "Cyan"

# Step 1: Create Traefik ConfigMap with self-signed certificate resolver
Write-Log "`nStep 1: Creating Traefik ConfigMap with self-signed certificate resolver..." "INFO" "Cyan"

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
        address: ":8080"
      websecure:
        address: ":443"
    providers:
      kubernetes:
        ingressClass: traefik
    certificatesResolvers:
      default:
        tls: {}
"@

try {
    $traefikConfig | kubectl apply -f -
    Write-Log "Traefik ConfigMap created successfully" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to create Traefik ConfigMap: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 2: Update all existing ingresses to use self-signed certificates
Write-Log "`nStep 2: Updating existing ingresses for local domains..." "INFO" "Cyan"

$namespaces = kubectl get namespaces -o json | ConvertFrom-Json
$blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }

foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    Write-Log "Processing namespace: $nsName" "INFO" "Yellow"
    
    try {
        # Get ingresses in this namespace
        $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
        if ($ingresses.items -and $ingresses.items.Count -gt 0) {
            foreach ($ingress in $ingresses.items) {
                $ingressName = $ingress.metadata.name
                $host = $ingress.spec.rules[0].host
                
                Write-Log "Updating ingress '$ingressName' for domain '$host'" "INFO" "Yellow"
                
                # Remove problematic annotations
                kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.middlewares- --overwrite -ErrorAction SilentlyContinue
                kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.rule- --overwrite -ErrorAction SilentlyContinue
                
                # Add self-signed SSL annotations
                kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.entrypoints=websecure --overwrite
                kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.tls=true --overwrite
                kubectl annotate ingress $ingressName -n $nsName traefik.ingress.kubernetes.io/router.tls.certresolver=default --overwrite
                
                Write-Log "Ingress '$ingressName' updated for local domain '$host'" "SUCCESS" "Green"
            }
        } else {
            Write-Log "No ingresses found in namespace $nsName" "WARNING" "Yellow"
        }
    } catch {
        Write-Log "Failed to process namespace $nsName: $($_.Exception.Message)" "ERROR" "Red"
    }
}

# Step 3: Create a template for new deployments
Write-Log "`nStep 3: Creating local domain ingress template..." "INFO" "Cyan"

$localIngressTemplate = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {CLIENT}-blog-template-ingress
  namespace: blog-{CLIENT}-dev
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: default
spec:
  tls:
  - hosts:
    - {DOMAIN}
    secretName: {CLIENT}-blog-template-tls
  rules:
  - host: {DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {CLIENT}-frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: {CLIENT}-backend
            port:
              number: 3000
"@

try {
    $templateFile = ".\Tools\local-domain-ingress-template.yaml"
    $localIngressTemplate | Out-File -FilePath $templateFile -Encoding UTF8
    Write-Log "Local domain ingress template saved to: $templateFile" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to save ingress template: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 4: Update hosts file with all blog domains
Write-Log "`nStep 4: Updating Windows hosts file..." "INFO" "Cyan"

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$hostsEntries = @()

foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    try {
        $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
        if ($ingresses.items -and $ingresses.items.Count -gt 0) {
            $host = $ingresses.items[0].spec.rules[0].host
            $hostsEntries += "127.0.0.1 $host"
        }
    } catch {
        Write-Log "Failed to get ingress for namespace $nsName" "WARNING" "Yellow"
    }
}

if ($hostsEntries.Count -gt 0) {
    Write-Log "`nAdd these entries to your hosts file ($hostsFile):" "INFO" "Cyan"
    foreach ($entry in $hostsEntries) {
        Write-Log "  $entry" "INFO" "White"
    }
    
    Write-Log "`nTo add automatically (requires admin privileges):" "INFO" "Yellow"
    Write-Log "Run as Administrator: Add-Content -Path '$hostsFile' -Value '$($hostsEntries -join \"`n\")'" "INFO" "Gray"
}

# Step 5: Create a summary of local domain configuration
Write-Log "`nStep 5: Creating local domain configuration summary..." "INFO" "Cyan"

$summaryFile = ".\logs\local-domains-config.txt"
$summary = @"
Local Domain SSL Configuration Summary
=====================================
Generated: $(Get-Date)

Self-Signed SSL Setup:
- Traefik configured with 'default' certificate resolver
- All ingresses updated to use websecure entrypoint
- TLS enabled for all local domains

Configured Domains:
"@

foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    try {
        $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
        if ($ingresses.items -and $ingresses.items.Count -gt 0) {
            $host = $ingresses.items[0].spec.rules[0].host
            $summary += "`n- $nsName:"
            $summary += "`n  Domain: $host"
            $summary += "`n  HTTPS: https://$host:8443/"
            $summary += "`n  HTTP:  http://$host:8080/"
        }
    } catch {
        # Skip failed namespaces
    }
}

$summary += "`n`nNotes:"
$summary += "`n- All domains use self-signed SSL certificates"
$summary += "`n- Add domains to hosts file for local resolution"
$summary += "`n- Use port 8443 for HTTPS access via Traefik"
$summary += "`n- Browser will show SSL warning (click 'Advanced' -> 'Proceed')"

try {
    if (!(Test-Path ".\logs")) {
        New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
    }
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Log "Local domain configuration summary saved to: $summaryFile" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to save summary: $($_.Exception.Message)" "ERROR" "Red"
}

# Final summary
Write-Log "`nLocal Domain SSL Configuration Complete!" "SUCCESS" "Green"
Write-Log "=========================================" "SUCCESS" "Green"
Write-Log "`nAll blog domains are now configured for local access with self-signed SSL" "INFO" "Cyan"
Write-Log "Summary saved to: $summaryFile" "INFO" "Cyan"
Write-Log "`nNext steps:" "INFO" "Yellow"
Write-Log "1. Add domains to hosts file (see output above)" "INFO" "White"
Write-Log "2. Start port forwarding: kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443" "INFO" "White"
Write-Log "3. Access blogs via HTTPS with self-signed certificates" "INFO" "White"
