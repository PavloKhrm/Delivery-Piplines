#Requires -Version 5.1
<#
.SYNOPSIS
    Removes a client deployment and cleans up all associated resources.

.DESCRIPTION
    This script safely removes a client deployment including:
    - Kubernetes namespace and all resources
    - Port allocation cleanup
    - Client configuration removal
    - Backup of configuration before deletion

.PARAMETER ClientName
    Name of the client to remove

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER BackupOnly
    Create backup without removing the client

.PARAMETER DryRun
    Preview what would be removed without executing

.EXAMPLE
    .\Remove-Client.ps1 -ClientName "acme-corp"

.EXAMPLE
    .\Remove-Client.ps1 -ClientName "test-client" -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ClientName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$BackupOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Configuration
$script:Config = @{
    ClientsConfigFile = "clients-config.json"
    UsedPortsFile = "used-ports.json"
    BackupPath = "backups"
    DeploymentsPath = "deployments"
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

function Save-ClientsConfig {
    param([hashtable]$ClientsConfig)
    $ClientsConfig | ConvertTo-Json -Depth 5 | Set-Content $Config.ClientsConfigFile
}

function Get-UsedPorts {
    if (Test-Path $Config.UsedPortsFile) {
        return Get-Content $Config.UsedPortsFile | ConvertFrom-Json
    }
    return @{}
}

function Save-UsedPorts {
    param([hashtable]$UsedPorts)
    $UsedPorts | ConvertTo-Json -Depth 3 | Set-Content $Config.UsedPortsFile
}

function Backup-ClientConfiguration {
    param(
        [hashtable]$ClientConfig,
        [string]$BackupPath
    )
    
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupFile = Join-Path $BackupPath "$ClientName-$timestamp.json"
    
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    
    $ClientConfig | ConvertTo-Json -Depth 5 | Set-Content $backupFile
    Write-Success "Client configuration backed up to: $backupFile"
    
    return $backupFile
}

function Remove-KubernetesResources {
    param(
        [string]$ClientName,
        [string]$Namespace
    )
    
    Write-Info "Removing Kubernetes resources for client: $ClientName"
    
    try {
        # Check if namespace exists
        $namespaceExists = kubectl get namespace $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Namespace '$Namespace' does not exist in Kubernetes"
            return $true
        }
        
        # Remove Helm release
        Write-Info "Removing Helm release..."
        $helmReleases = helm list -n $Namespace --short 2>$null
        if ($LASTEXITCODE -eq 0 -and $helmReleases) {
            foreach ($release in ($helmReleases -split "`n" | Where-Object { $_.Trim() })) {
                if (-not $DryRun) {
                    helm uninstall $release -n $Namespace --wait --timeout=5m
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Removed Helm release: $release"
                    } else {
                        Write-Warning "Failed to remove Helm release: $release"
                    }
                } else {
                    Write-Info "Would remove Helm release: $release"
                }
            }
        }
        
        # Remove namespace (this will remove all resources)
        if (-not $DryRun) {
            kubectl delete namespace $Namespace --wait=true --timeout=300s
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Removed namespace: $Namespace"
            } else {
                Write-Warning "Failed to remove namespace: $Namespace"
                return $false
            }
        } else {
            Write-Info "Would remove namespace: $Namespace"
        }
        
        return $true
        
    } catch {
        Write-Error "Error removing Kubernetes resources: $($_.Exception.Message)"
        return $false
    }
}

function Release-AllocatedPorts {
    param([hashtable]$ClientConfig)
    
    Write-Info "Releasing allocated ports for client: $($ClientConfig.name)"
    
    $usedPorts = Get-UsedPorts
    $releasedPorts = @()
    
    foreach ($service in $ClientConfig.ports.Keys) {
        $port = $ClientConfig.ports[$service].external
        if ($usedPorts.ContainsKey($port.ToString())) {
            if (-not $DryRun) {
                $usedPorts.Remove($port.ToString())
            }
            $releasedPorts += "$service`:$port"
        }
    }
    
    if (-not $DryRun -and $releasedPorts.Count -gt 0) {
        Save-UsedPorts -UsedPorts $usedPorts
        Write-Success "Released ports: $($releasedPorts -join ', ')"
    } elseif ($DryRun) {
        Write-Info "Would release ports: $($releasedPorts -join ', ')"
    }
}

function Remove-DeploymentFiles {
    param([string]$ClientName)
    
    $deploymentPath = Join-Path $Config.DeploymentsPath $ClientName
    
    if (Test-Path $deploymentPath) {
        if (-not $DryRun) {
            Remove-Item -Path $deploymentPath -Recurse -Force
            Write-Success "Removed deployment files: $deploymentPath"
        } else {
            Write-Info "Would remove deployment files: $deploymentPath"
        }
    } else {
        Write-Info "Deployment directory does not exist: $deploymentPath"
    }
}

function Show-RemovalSummary {
    param([hashtable]$ClientConfig)
    
    Write-Info "`nRemoval Summary for: $($ClientConfig.name)"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "Environment: $($ClientConfig.environment)" -ForegroundColor White
    Write-Host "Namespace: $($ClientConfig.namespace)" -ForegroundColor White
    Write-Host "Domain: $($ClientConfig.domain)" -ForegroundColor White
    Write-Host "Created: $($ClientConfig.createdAt)" -ForegroundColor White
    
    Write-Host "`nResources to be removed:" -ForegroundColor Yellow
    Write-Host "  ✓ Kubernetes namespace and all pods/services" -ForegroundColor White
    Write-Host "  ✓ Persistent volumes and data" -ForegroundColor White
    Write-Host "  ✓ Helm releases" -ForegroundColor White
    Write-Host "  ✓ Port allocations:" -ForegroundColor White
    
    foreach ($service in $ClientConfig.ports.Keys) {
        $port = $ClientConfig.ports[$service]
        Write-Host "    - $service`: $($port.external)" -ForegroundColor Gray
    }
    
    Write-Host "  ✓ Deployment files and scripts" -ForegroundColor White
    Write-Host "  ✓ Client configuration registry" -ForegroundColor White
    
    Write-Host "`n" -NoNewline
    Write-Warning "⚠️  This action cannot be undone!"
    Write-Warning "⚠️  All data in persistent volumes will be lost!"
}

# Main execution
try {
    Write-Info "Client Removal Tool"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    # Load client configuration
    $clientsConfig = Get-ClientsConfig
    
    if (-not $clientsConfig.ContainsKey($ClientName)) {
        Write-Error "Client '$ClientName' not found in configuration"
        Write-Info "Available clients: $($clientsConfig.Keys -join ', ')"
        exit 1
    }
    
    $clientConfig = $clientsConfig[$ClientName]
    
    # Show what will be removed
    Show-RemovalSummary -ClientConfig $clientConfig
    
    # Create backup
    if (-not $DryRun) {
        $backupFile = Backup-ClientConfiguration -ClientConfig $clientConfig -BackupPath $Config.BackupPath
    } else {
        Write-Info "`nWould create backup in: $($Config.BackupPath)"
    }
    
    if ($BackupOnly) {
        Write-Success "`nBackup completed. Client configuration preserved."
        exit 0
    }
    
    # Confirmation
    if (-not $Force -and -not $DryRun) {
        Write-Host "`n" -NoNewline
        $confirmation = Read-Host "Are you sure you want to remove client '$ClientName'? Type 'yes' to confirm"
        if ($confirmation -ne "yes") {
            Write-Info "Operation cancelled"
            exit 0
        }
    }
    
    if ($DryRun) {
        Write-Info "`n=== DRY RUN MODE - No changes will be made ===`n"
    }
    
    # Remove Kubernetes resources
    $kubeSuccess = Remove-KubernetesResources -ClientName $ClientName -Namespace $clientConfig.namespace
    
    if ($kubeSuccess -or $DryRun) {
        # Release ports
        Release-AllocatedPorts -ClientConfig $clientConfig
        
        # Remove deployment files
        Remove-DeploymentFiles -ClientName $ClientName
        
        # Remove from client registry
        if (-not $DryRun) {
            $clientsConfig.Remove($ClientName)
            Save-ClientsConfig -ClientsConfig $clientsConfig
            Write-Success "Removed client from registry"
        } else {
            Write-Info "Would remove client from registry"
        }
        
        Write-Host "`n" -NoNewline
        if ($DryRun) {
            Write-Success "Dry run completed. No actual changes were made."
        } else {
            Write-Success "Client '$ClientName' has been successfully removed!"
            Write-Info "Configuration backup available at: $backupFile"
        }
    } else {
        Write-Error "Failed to remove Kubernetes resources. Aborting cleanup."
        exit 1
    }
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    exit 1
}
