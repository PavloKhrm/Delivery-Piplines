#Requires -Version 5.1
<#
.SYNOPSIS
    Lists all deployed clients and their configurations.

.DESCRIPTION
    Displays a comprehensive overview of all client deployments including:
    - Client names and environments
    - Allocated ports and domains
    - Deployment status
    - Resource utilization

.PARAMETER Environment
    Filter by environment: dev, staging, production

.PARAMETER Status
    Show deployment status from Kubernetes

.PARAMETER Detailed
    Show detailed configuration information

.EXAMPLE
    .\List-Clients.ps1

.EXAMPLE
    .\List-Clients.ps1 -Environment production -Status
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [switch]$Status,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Configuration
$script:Config = @{
    ClientsConfigFile = "clients-config.json"
    UsedPortsFile = "used-ports.json"
}

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

function Get-ClientsConfig {
    if (Test-Path $Config.ClientsConfigFile) {
        return Get-Content $Config.ClientsConfigFile | ConvertFrom-Json
    }
    return @{}
}

function Get-KubernetesStatus {
    param([string]$Namespace)
    
    try {
        $pods = kubectl get pods -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $pods) {
            $podLines = $pods -split "`n" | Where-Object { $_.Trim() }
            $totalPods = $podLines.Count
            $runningPods = ($podLines | Where-Object { $_ -match "\s+Running\s+" }).Count
            $readyPods = ($podLines | Where-Object { $_ -match "\s+\d+/\d+\s+Running\s+" -and $_ -match "\s+\d+/\d+\s+" } | ForEach-Object {
                if ($_ -match "(\d+)/(\d+)") {
                    if ($matches[1] -eq $matches[2]) { 1 } else { 0 }
                }
            } | Measure-Object -Sum).Sum
            
            return @{
                exists = $true
                totalPods = $totalPods
                runningPods = $runningPods
                readyPods = $readyPods
                status = if ($readyPods -eq $totalPods -and $totalPods -gt 0) { "Healthy" } 
                        elseif ($runningPods -gt 0) { "Partial" } 
                        else { "Failed" }
            }
        }
        return @{ exists = $false; status = "Not Deployed" }
    } catch {
        return @{ exists = $false; status = "Unknown" }
    }
}

function Format-ClientSummary {
    param(
        [hashtable]$Client,
        [hashtable]$KubeStatus = @{}
    )
    
    $statusColor = switch ($KubeStatus.status) {
        "Healthy" { "Green" }
        "Partial" { "Yellow" }
        "Failed" { "Red" }
        default { "Gray" }
    }
    
    Write-Host "┌─ " -NoNewline
    Write-Host $Client.name -ForegroundColor Cyan -NoNewline
    Write-Host " ($($Client.environment))" -ForegroundColor White
    
    Write-Host "├── Domain: " -NoNewline
    Write-Host $Client.domain -ForegroundColor Yellow
    
    Write-Host "├── Namespace: " -NoNewline
    Write-Host $Client.namespace -ForegroundColor Magenta
    
    Write-Host "├── Created: " -NoNewline
    Write-Host $Client.createdAt -ForegroundColor White
    
    if ($Status -and $KubeStatus.exists) {
        Write-Host "├── Status: " -NoNewline
        Write-Host $KubeStatus.status -ForegroundColor $statusColor -NoNewline
        Write-Host " ($($KubeStatus.readyPods)/$($KubeStatus.totalPods) pods ready)" -ForegroundColor Gray
    }
    
    Write-Host "├── Ports:" -ForegroundColor White
    foreach ($service in $Client.ports.Keys) {
        $port = $Client.ports[$service]
        Write-Host "│   ├── $service`: " -NoNewline -ForegroundColor Gray
        Write-Host "$($port.internal) -> $($port.external)" -ForegroundColor White
    }
    
    if ($Detailed) {
        Write-Host "├── Cloud API: " -NoNewline
        if ($Client.cloudApi.endpoint) {
            Write-Host $Client.cloudApi.endpoint -ForegroundColor Green
        } else {
            Write-Host "Not configured" -ForegroundColor Gray
        }
        
        Write-Host "├── CI/CD: " -NoNewline
        if ($Client.cicd.bitbucketRepo) {
            Write-Host $Client.cicd.bitbucketRepo -ForegroundColor Green
        } else {
            Write-Host "Not configured" -ForegroundColor Gray
        }
        
        Write-Host "└── Secrets: " -NoNewline
        Write-Host "$($Client.secrets.Keys.Count) configured" -ForegroundColor Yellow
    } else {
        Write-Host "└── " -NoNewline
        Write-Host "Access: http://$($Client.domain)" -ForegroundColor Blue
    }
    
    Write-Host ""
}

function Show-PortUtilization {
    param([hashtable]$ClientsConfig)
    
    $allPorts = @()
    foreach ($client in $ClientsConfig.Values) {
        foreach ($service in $client.ports.Keys) {
            $allPorts += $client.ports[$service].external
        }
    }
    
    $minPort = ($allPorts | Measure-Object -Minimum).Minimum
    $maxPort = ($allPorts | Measure-Object -Maximum).Maximum
    $totalUsed = $allPorts.Count
    
    Write-Info "Port Utilization Summary:"
    Write-Host "  Range Used: $minPort - $maxPort" -ForegroundColor White
    Write-Host "  Total Ports Allocated: $totalUsed" -ForegroundColor White
    Write-Host "  Clients: $($ClientsConfig.Count)" -ForegroundColor White
    Write-Host ""
}

# Main execution
try {
    Write-Info "Client Deployment Overview"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    
    $clientsConfig = Get-ClientsConfig
    
    if ($clientsConfig.Count -eq 0) {
        Write-Warning "No clients found. Use Generate-ClientDeployment.ps1 to create your first deployment."
        exit 0
    }
    
    # Filter by environment if specified
    $filteredClients = if ($Environment) {
        $clientsConfig.GetEnumerator() | Where-Object { $_.Value.environment -eq $Environment }
    } else {
        $clientsConfig.GetEnumerator()
    }
    
    if ($filteredClients.Count -eq 0) {
        Write-Warning "No clients found for environment: $Environment"
        exit 0
    }
    
    # Show port utilization summary
    Show-PortUtilization -ClientsConfig $clientsConfig
    
    # List clients
    foreach ($clientEntry in ($filteredClients | Sort-Object { $_.Value.createdAt })) {
        $client = $clientEntry.Value
        $kubeStatus = @{}
        
        if ($Status) {
            Write-Host "Checking status for $($client.name)..." -ForegroundColor Gray
            $kubeStatus = Get-KubernetesStatus -Namespace $client.namespace
        }
        
        Format-ClientSummary -Client $client -KubeStatus $kubeStatus
    }
    
    # Summary statistics
    $totalClients = $filteredClients.Count
    $envGroups = $filteredClients | Group-Object { $_.Value.environment }
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Info "Summary: $totalClients client(s) total"
    
    foreach ($group in $envGroups) {
        Write-Host "  $($group.Name): $($group.Count) client(s)" -ForegroundColor White
    }
    
    if ($Status) {
        $healthyCount = 0
        $partialCount = 0
        $failedCount = 0
        
        foreach ($clientEntry in $filteredClients) {
            $kubeStatus = Get-KubernetesStatus -Namespace $clientEntry.Value.namespace
            switch ($kubeStatus.status) {
                "Healthy" { $healthyCount++ }
                "Partial" { $partialCount++ }
                "Failed" { $failedCount++ }
            }
        }
        
        Write-Host ""
        Write-Info "Health Status:"
        Write-Host "  Healthy: " -NoNewline
        Write-Host $healthyCount -ForegroundColor Green
        Write-Host "  Partial: " -NoNewline
        Write-Host $partialCount -ForegroundColor Yellow
        Write-Host "  Failed: " -NoNewline
        Write-Host $failedCount -ForegroundColor Red
    }
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
