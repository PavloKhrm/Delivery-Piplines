#Requires -Version 5.1
<#
.SYNOPSIS
    Generates isolated Kubernetes deployment for a new client using Helm templates.

.DESCRIPTION
    This script creates a complete isolated environment for a client including:
    - Unique namespace
    - Dynamic port allocation
    - Auto-generated passwords and secrets
    - Custom domain configuration
    - Helm values file generation
    - Environment configuration files

.PARAMETER ClientName
    Name of the client (alphanumeric, lowercase, hyphens allowed)

.PARAMETER Domain
    Custom domain for the client (optional, auto-generated if not provided)

.PARAMETER Environment
    Target environment: dev, staging, production (default: dev)

.PARAMETER CloudApiEndpoint
    Cloud API server endpoint for data synchronization

.PARAMETER BitbucketRepo
    Bitbucket repository for CI/CD integration

.PARAMETER DryRun
    Preview changes without executing them

.EXAMPLE
    .\Generate-ClientDeployment.ps1 -ClientName "acme-corp" -Environment "production"

.EXAMPLE
    .\Generate-ClientDeployment.ps1 -ClientName "test-client" -Domain "test.example.com" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-z0-9][a-z0-9\-]*[a-z0-9]$")]
    [string]$ClientName,
    
    [Parameter(Mandatory = $false)]
    [string]$Domain,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory = $false)]
    [string]$CloudApiEndpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$BitbucketRepo,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmations and regenerate non-interactively")]
    [switch]$Force
)

# Configuration
$script:Config = @{
    HelmChartPath = "helm-blog-template"
    DeploymentsPath = "deployments"
    PortRangeStart = 30000
    PortRangeEnd = 32767
    UsedPortsFile = "used-ports.json"
    ClientsConfigFile = "clients-config.json"
    PasswordLength = 32
    SecretLength = 64
}

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $requiredTools = @("helm", "kubectl", "docker")
    $missing = @()
    
    foreach ($tool in $requiredTools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing required tools: $($missing -join ', ')"
        return $false
    }
    
    # Check if Kubernetes cluster is accessible
    try {
        $null = kubectl cluster-info --request-timeout=5s 2>$null
        Write-Success "Kubernetes cluster is accessible"
    } catch {
        Write-Error "Cannot connect to Kubernetes cluster"
        return $false
    }
    
    # Check if Helm chart exists
    if (-not (Test-Path $Config.HelmChartPath)) {
        Write-Error "Helm chart not found at: $($Config.HelmChartPath)"
        return $false
    }
    
    Write-Success "All prerequisites satisfied"
    return $true
}

function Get-UsedPorts {
    if (Test-Path $Config.UsedPortsFile) {
        $jsonContent = Get-Content $Config.UsedPortsFile | ConvertFrom-Json
        # Convert PSCustomObject to hashtable for PowerShell 5.1 compatibility
        $hashtable = @{}
        if ($jsonContent) {
            $jsonContent.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = $_.Value
            }
        }
        return $hashtable
    }
    return @{}
}

function Save-UsedPorts {
    param([hashtable]$UsedPorts)
    $UsedPorts | ConvertTo-Json -Depth 3 | Set-Content $Config.UsedPortsFile -Encoding UTF8
}

function Get-ClientsConfig {
    if (Test-Path $Config.ClientsConfigFile) {
        $jsonContent = Get-Content $Config.ClientsConfigFile | ConvertFrom-Json
        # Convert PSCustomObject to hashtable for PowerShell 5.1 compatibility
        $hashtable = @{}
        if ($jsonContent) {
            $jsonContent.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = $_.Value
            }
        }
        return $hashtable
    }
    return @{}
}

function Save-ClientsConfig {
    param([hashtable]$ClientsConfig)
    $ClientsConfig | ConvertTo-Json -Depth 5 | Set-Content $Config.ClientsConfigFile -Encoding UTF8
}

function Get-AvailablePorts {
    param([int]$Count = 6)
    
    $usedPorts = Get-UsedPorts
    $availablePorts = @()
    
    for ($port = $Config.PortRangeStart; $port -le $Config.PortRangeEnd -and $availablePorts.Count -lt $Count; $port++) {
        if (-not $usedPorts.ContainsKey($port.ToString())) {
            $availablePorts += $port
        }
    }
    
    if ($availablePorts.Count -lt $Count) {
        throw "Not enough available ports in range $($Config.PortRangeStart)-$($Config.PortRangeEnd)"
    }
    
    return $availablePorts
}

function New-SecurePassword {
    param([int]$Length = 32)
    
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    $random = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $random.GetBytes($bytes)
        $password += $chars[$bytes[0] % $chars.Length]
    }
    
    $random.Dispose()
    return $password
}

function New-ClientConfiguration {
    param(
        [string]$ClientName,
        [string]$Domain,
        [string]$Environment
    )
    
    Write-Info "Generating configuration for client: $ClientName"
    
    # Generate namespace
    $namespace = "blog-$ClientName-$Environment"
    
    # Generate domain if not provided
    if (-not $Domain) {
        $Domain = "$ClientName.$Environment.local"
    }
    
    # Allocate ports
    $ports = Get-AvailablePorts -Count 6
    
    # Generate secrets
    $secrets = @{
        DatabasePassword = New-SecurePassword -Length $Config.PasswordLength
        RedisPassword = New-SecurePassword -Length $Config.PasswordLength
        ElasticsearchPassword = New-SecurePassword -Length $Config.PasswordLength
        JwtSecret = New-SecurePassword -Length $Config.SecretLength
        SessionSecret = New-SecurePassword -Length $Config.SecretLength
        ClientApiKey = New-SecurePassword -Length $Config.SecretLength
        WebhookSecret = New-SecurePassword -Length $Config.PasswordLength
    }
    
    # Create client configuration
    $clientConfig = @{
        name = $ClientName
        namespace = $namespace
        domain = $Domain
        environment = $Environment
        createdAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        ports = @{
            backend = @{ internal = 3000; external = $ports[0] }
            frontend = @{ internal = 80; external = $ports[1] }
            mysql = @{ internal = 3306; external = $ports[2] }
            redis = @{ internal = 6379; external = $ports[3] }
            elasticsearch = @{ internal = 9200; external = $ports[4] }
            mailcrab = @{ internal = 1080; external = $ports[5] }
        }
        secrets = $secrets
        cloudApi = @{
            endpoint = $CloudApiEndpoint
            apiKey = $secrets.ClientApiKey
        }
        cicd = @{
            bitbucketRepo = $BitbucketRepo
            webhookSecret = $secrets.WebhookSecret
        }
    }
    
    return $clientConfig
}

function New-HelmValuesFile {
    param(
        [hashtable]$ClientConfig,
        [string]$OutputPath
    )
    
    $values = @"
# Generated values for client: $($ClientConfig.name)
# Created: $($ClientConfig.createdAt)
# Environment: $($ClientConfig.environment)

# Client configuration
client:
  name: "$($ClientConfig.name)"
  namespace: "$($ClientConfig.namespace)"
  domain: "$($ClientConfig.domain)"

# Port allocation
ports:
  backend:
    internal: $($ClientConfig.ports.backend.internal)
    external: $($ClientConfig.ports.backend.external)
  frontend:
    internal: $($ClientConfig.ports.frontend.internal)
    external: $($ClientConfig.ports.frontend.external)
  mysql:
    internal: $($ClientConfig.ports.mysql.internal)
    external: $($ClientConfig.ports.mysql.external)
  redis:
    internal: $($ClientConfig.ports.redis.internal)
    external: $($ClientConfig.ports.redis.external)
  elasticsearch:
    internal: $($ClientConfig.ports.elasticsearch.internal)
    external: $($ClientConfig.ports.elasticsearch.external)
  mailcrab:
    internal: $($ClientConfig.ports.mailcrab.internal)
    external: $($ClientConfig.ports.mailcrab.external)

# Pre-generated secrets
env:
  database:
    password: "$($ClientConfig.secrets.DatabasePassword)"
  redis:
    password: "$($ClientConfig.secrets.RedisPassword)"
  elasticsearch:
    password: "$($ClientConfig.secrets.ElasticsearchPassword)"
  app:
    jwtSecret: "$($ClientConfig.secrets.JwtSecret)"
    sessionSecret: "$($ClientConfig.secrets.SessionSecret)"

    # Health checks
    healthChecks:
      enabled: true
      backend:
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5

    # SSL/TLS configuration
    ssl:
      enabled: true
      certResolver: default
      redirectHttpToHttps: true

# Environment-specific settings
$(if ($ClientConfig.environment -eq "production") {
@"
replicas:
  backend: 3
  frontend: 2

resources:
  backend:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

persistence:
  mysql:
    size: 50Gi
  redis:
    size: 10Gi
  elasticsearch:
    size: 100Gi

ingress:
  tls:
    enabled: true
"@
} elseif ($ClientConfig.environment -eq "staging") {
@"
replicas:
  backend: 2
  frontend: 1

persistence:
  mysql:
    size: 20Gi
  redis:
    size: 5Gi
  elasticsearch:
    size: 30Gi
"@
} else {
@"
replicas:
  backend: 1
  frontend: 1

persistence:
  mysql:
    size: 10Gi
  redis:
    size: 2Gi
  elasticsearch:
    size: 10Gi
"@
})

# Security configuration
security:
  networkPolicies:
    enabled: true
  podSecurityContext:
    enabled: true

# Monitoring
monitoring:
  enabled: $(if ($ClientConfig.environment -eq "production") { "true" } else { "false" })

# Auto-scaling (production only)
autoscaling:
  enabled: $(if ($ClientConfig.environment -eq "production") { "true" } else { "false" })
"@

    $values | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Success "Generated Helm values file: $OutputPath"
}

function New-EnvironmentFile {
    param(
        [hashtable]$ClientConfig,
        [string]$OutputPath
    )
    
    $envContent = @"
# Environment configuration for $($ClientConfig.name)
# Generated: $($ClientConfig.createdAt)

# Application
NODE_ENV=$($ClientConfig.environment)
APP_TIMEZONE=UTC
CLIENT_NAME=$($ClientConfig.name)
CLIENT_DOMAIN=$($ClientConfig.domain)

# Database
DATABASE_HOST=$($ClientConfig.name)-mysql.$($ClientConfig.namespace).svc.cluster.local
DATABASE_PORT=$($ClientConfig.ports.mysql.internal)
DATABASE_NAME=blog_db
DATABASE_USERNAME=blog_user
DATABASE_PASSWORD=$($ClientConfig.secrets.DatabasePassword)

# Redis
REDIS_HOST=$($ClientConfig.name)-redis.$($ClientConfig.namespace).svc.cluster.local
REDIS_PORT=$($ClientConfig.ports.redis.internal)
REDIS_PASSWORD=$($ClientConfig.secrets.RedisPassword)

# Elasticsearch
ELASTICSEARCH_HOST=$($ClientConfig.name)-elasticsearch.$($ClientConfig.namespace).svc.cluster.local
ELASTICSEARCH_PORT=$($ClientConfig.ports.elasticsearch.internal)
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=$($ClientConfig.secrets.ElasticsearchPassword)

# Mail
MAIL_HOST=$($ClientConfig.name)-mailcrab.$($ClientConfig.namespace).svc.cluster.local
MAIL_PORT=1025
MAIL_USER=test
MAIL_PASSWORD=test

# Security
JWT_SECRET=$($ClientConfig.secrets.JwtSecret)
SESSION_SECRET=$($ClientConfig.secrets.SessionSecret)

# Cloud API Integration
$(if ($ClientConfig.cloudApi.endpoint) {
@"
CLOUD_API_ENDPOINT=$($ClientConfig.cloudApi.endpoint)
CLOUD_API_KEY=$($ClientConfig.secrets.ClientApiKey)
"@
})

# CI/CD Integration
$(if ($ClientConfig.cicd.bitbucketRepo) {
@"
BITBUCKET_REPO=$($ClientConfig.cicd.bitbucketRepo)
WEBHOOK_SECRET=$($ClientConfig.secrets.WebhookSecret)
"@
})
"@

    $envContent | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Success "Generated environment file: $OutputPath"
}

function New-DeploymentScripts {
    param(
        [hashtable]$ClientConfig,
        [string]$DeploymentPath
    )
    
    # Deploy script
    $deployScript = @"
#!/bin/bash
# Deployment script for $($ClientConfig.name)

set -e

echo "Deploying $($ClientConfig.name) to $($ClientConfig.environment)..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:latest `$PSScriptRoot/../../basic-blog/basic-backend/
docker build -t blog-frontend:latest `$PSScriptRoot/../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
Push-Location `$PSScriptRoot
try {
    helm upgrade --install $($ClientConfig.name) ../../helm-blog-template \
      --namespace $($ClientConfig.namespace) \
      --create-namespace \
      --values values.yaml \
      --wait \
      --timeout=10m
} finally {
    Pop-Location
}

echo "Deployment completed successfully!"

# Auto-fix for local websites
echo "Setting up local website access..."

# Add domain to hosts file (Windows)
HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
HOST_ENTRY="127.0.0.1 $($ClientConfig.domain)"

if [ -f "`$HOSTS_FILE" ]; then
    if ! grep -q "`$HOST_ENTRY" "`$HOSTS_FILE"; then
        echo "`$HOST_ENTRY" | sudo tee -a "`$HOSTS_FILE" > /dev/null
        echo "Added domain to hosts file: $($ClientConfig.domain)"
    fi
else
    echo "Could not auto-update hosts file. Please add manually: 127.0.0.1 $($ClientConfig.domain)"
fi

# Start port forwarding if not already running
if ! pgrep -f "kubectl port-forward.*traefik" > /dev/null; then
    kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443 &
    echo "Started Traefik port forwarding"
    sleep 3
fi

echo ""
echo "Your website is now accessible at:"
echo "  HTTPS: https://$($ClientConfig.domain):8443/"
echo "  HTTP:  http://$($ClientConfig.domain):8080/"
echo ""
echo "Note: Browser will show SSL warning - click 'Advanced' -> 'Proceed'"
echo ""
echo "External ports allocated:"
echo "  Frontend: $($ClientConfig.ports.frontend.external)"
echo "  Backend: $($ClientConfig.ports.backend.external)"
echo "  MySQL: $($ClientConfig.ports.mysql.external)"
echo "  Redis: $($ClientConfig.ports.redis.external)"
echo "  Elasticsearch: $($ClientConfig.ports.elasticsearch.external)"
echo "  MailCrab: $($ClientConfig.ports.mailcrab.external)"
"@

    $deployScript | Set-Content -Path "$DeploymentPath/deploy.sh" -Encoding UTF8
    
    # PowerShell deploy script
    $deployPsScript = @"
# PowerShell deployment script for $($ClientConfig.name)

`$ErrorActionPreference = "Stop"

Write-Host "Deploying $($ClientConfig.name) to $($ClientConfig.environment)..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:latest `$PSScriptRoot/../../basic-blog/basic-backend/
docker build -t blog-frontend:latest `$PSScriptRoot/../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install $($ClientConfig.name) `$PSScriptRoot/../../helm-blog-template ``
  --namespace $($ClientConfig.namespace) ``
  --create-namespace ``
  --values `$PSScriptRoot/values.yaml ``
  --wait ``
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green

# Auto-fix for local websites
Write-Host "Setting up local website access..." -ForegroundColor Yellow

# Add domain to hosts file
`$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
`$hostEntry = "127.0.0.1 $($ClientConfig.domain)"
try {
    `$currentHosts = Get-Content `$hostsFile -ErrorAction SilentlyContinue
    if (`$currentHosts -notcontains `$hostEntry) {
        Add-Content -Path `$hostsFile -Value `$hostEntry -ErrorAction SilentlyContinue
        Write-Host "Added domain to hosts file: $($ClientConfig.domain)" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not auto-update hosts file. Please add manually: 127.0.0.1 $($ClientConfig.domain)" -ForegroundColor Yellow
}

# Start port forwarding if not already running
`$existingJobs = Get-Job -Name "traefik-forward" -ErrorAction SilentlyContinue
if (-not `$existingJobs) {
    Start-Job -Name "traefik-forward" -ScriptBlock { 
        kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443 
    } | Out-Null
    Write-Host "Started Traefik port forwarding" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Write-Host "`nYour website is now accessible at:" -ForegroundColor Cyan
Write-Host "  HTTPS: https://$($ClientConfig.domain):8443/" -ForegroundColor Green
Write-Host "  HTTP:  http://$($ClientConfig.domain):8080/" -ForegroundColor Green
Write-Host "`nNote: Browser will show SSL warning - click 'Advanced' -> 'Proceed'" -ForegroundColor Yellow
Write-Host "`nExternal ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: $($ClientConfig.ports.frontend.external)" -ForegroundColor White
Write-Host "  Backend: $($ClientConfig.ports.backend.external)" -ForegroundColor White
Write-Host "  MySQL: $($ClientConfig.ports.mysql.external)" -ForegroundColor White
Write-Host "  Redis: $($ClientConfig.ports.redis.external)" -ForegroundColor White
Write-Host "  Elasticsearch: $($ClientConfig.ports.elasticsearch.external)" -ForegroundColor White
Write-Host "  MailCrab: $($ClientConfig.ports.mailcrab.external)" -ForegroundColor White
"@

    $deployPsScript | Set-Content -Path "$DeploymentPath/deploy.ps1" -Encoding UTF8
    
    Write-Success "Generated deployment scripts in: $DeploymentPath"
}

function Update-PortAllocation {
    param([hashtable]$ClientConfig)
    
    $usedPorts = Get-UsedPorts
    
    # Mark ports as used
    foreach ($service in $ClientConfig.ports.Keys) {
        $port = $ClientConfig.ports[$service].external
        $usedPorts[$port.ToString()] = @{
            client = $ClientConfig.name
            service = $service
            allocatedAt = $ClientConfig.createdAt
        }
    }
    
    Save-UsedPorts -UsedPorts $usedPorts
    Write-Success "Updated port allocation registry"
}

function Update-ClientRegistry {
    param([hashtable]$ClientConfig)
    
    $clientsConfig = Get-ClientsConfig
    $clientsConfig[$ClientConfig.name] = $ClientConfig
    
    Save-ClientsConfig -ClientsConfig $clientsConfig
    Write-Success "Updated client registry"
}

# Main execution
try {
    Write-Info "Starting client deployment generation for: $ClientName"
    
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Check if client already exists
    $existingClients = Get-ClientsConfig
    if ($existingClients.ContainsKey($ClientName)) {
        Write-Warning "Client '$ClientName' already exists!"
        if (-not $Force) {
            $response = Read-Host "Do you want to regenerate? (y/N)"
            if ($response -ne "y" -and $response -ne "Y") {
                Write-Info "Operation cancelled"
                exit 0
            }
        } else {
            Write-Info "Force flag detected. Proceeding to regenerate without prompt."
        }
    }
    
    # Generate client configuration
    $clientConfig = New-ClientConfiguration -ClientName $ClientName -Domain $Domain -Environment $Environment
    
    # Create deployment directory
    $deploymentPath = Join-Path $Config.DeploymentsPath $ClientName
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $deploymentPath -Force | Out-Null
        Write-Success "Created deployment directory: $deploymentPath"
    } else {
        Write-Info "Would create deployment directory: $deploymentPath"
    }
    
    # Generate files
    $valuesFile = Join-Path $deploymentPath "values.yaml"
    $envFile = Join-Path $deploymentPath ".env"
    
    if (-not $DryRun) {
        New-HelmValuesFile -ClientConfig $clientConfig -OutputPath $valuesFile
        New-EnvironmentFile -ClientConfig $clientConfig -OutputPath $envFile
        New-DeploymentScripts -ClientConfig $clientConfig -DeploymentPath $deploymentPath
        
        # Update registries
        Update-PortAllocation -ClientConfig $clientConfig
        Update-ClientRegistry -ClientConfig $clientConfig
    } else {
        Write-Info "Would generate files:"
        Write-Info "  - $valuesFile"
        Write-Info "  - $envFile"
        Write-Info "  - $deploymentPath/deploy.sh"
        Write-Info "  - $deploymentPath/deploy.ps1"
    }
    
    # Display summary
    Write-Success "`nClient deployment configuration generated successfully!"
    Write-Info "Summary:"
    Write-Info "  Client: $($clientConfig.name)"
    Write-Info "  Namespace: $($clientConfig.namespace)"
    Write-Info "  Domain: $($clientConfig.domain)"
    Write-Info "  Environment: $($clientConfig.environment)"
    Write-Info "  Allocated Ports: $($clientConfig.ports.backend.external), $($clientConfig.ports.frontend.external), $($clientConfig.ports.mysql.external), $($clientConfig.ports.redis.external), $($clientConfig.ports.elasticsearch.external), $($clientConfig.ports.mailcrab.external)"
    
    if (-not $DryRun) {
        Write-Info "`nNext steps:"
        Write-Info "  1. Review generated files in: $deploymentPath"
        Write-Info "  2. Run deployment: cd $deploymentPath && ./deploy.ps1"
        Write-Info "  3. Your website will be automatically accessible at:"
        Write-Info "     - HTTPS: https://$($clientConfig.domain):8443/"
        Write-Info "     - HTTP:  http://$($clientConfig.domain):8080/"
        Write-Info "  4. Browser will show SSL warning - click 'Advanced' -> 'Proceed'"
    }
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    exit 1
}
