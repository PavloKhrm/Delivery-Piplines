# Simple client listing script for PowerShell 5.1

param(
    [string]$Environment
)

function Get-ClientsConfig {
    if (Test-Path "clients-config.json") {
        return Get-Content "clients-config.json" | ConvertFrom-Json
    }
    return @{}
}

Write-Host "Multi-Tenant Blog Template - Client Overview" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor DarkGray

$clientsConfig = Get-ClientsConfig

if ($clientsConfig.PSObject.Properties.Count -eq 0) {
    Write-Host "No clients found. Use Generate-ClientDeployment.ps1 to create deployments." -ForegroundColor Yellow
    exit 0
}

foreach ($clientName in $clientsConfig.PSObject.Properties.Name) {
    $client = $clientsConfig.$clientName
    
    if ($Environment -and $client.environment -ne $Environment) {
        continue
    }
    
    Write-Host ""
    Write-Host "Client: $($client.name)" -ForegroundColor Green
    Write-Host "  Environment: $($client.environment)" -ForegroundColor White
    Write-Host "  Namespace: $($client.namespace)" -ForegroundColor White  
    Write-Host "  Domain: $($client.domain)" -ForegroundColor White
    Write-Host "  Created: $($client.createdAt)" -ForegroundColor White
    Write-Host "  Ports:" -ForegroundColor White
    
    foreach ($serviceName in $client.ports.PSObject.Properties.Name) {
        $port = $client.ports.$serviceName
        Write-Host "    $serviceName : $($port.internal) -> $($port.external)" -ForegroundColor Gray
    }
    
    Write-Host "  Access: http://$($client.domain)" -ForegroundColor Blue
}

Write-Host ""
Write-Host "Total clients: $($clientsConfig.PSObject.Properties.Count)" -ForegroundColor Cyan
