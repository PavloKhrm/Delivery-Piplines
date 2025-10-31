[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId
)

$ErrorActionPreference = 'Stop'

# Get the folder where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Build absolute paths to the chart and values.yaml
$ChartPath = Join-Path $ScriptDir "charts\client-stack"
$ValuesFile = Join-Path $ChartPath "values.yaml"

$ns = "client-$ClientId"

Write-Host "Creating namespace $ns..." -ForegroundColor Cyan
kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "Installing client stack for $ClientId..." -ForegroundColor Cyan
helm upgrade --install $ClientId `
    $ChartPath `
    --namespace $ns `
    --create-namespace `
    --set clientId=$ClientId `
    --wait --timeout 5m

# Read baseDomain from the values file
$baseDomainLine = Get-Content $ValuesFile | Select-String -SimpleMatch "baseDomain:"
$BaseDomain = ($baseDomainLine -split ":")[1].Trim()

Write-Host "Done. Open:" -ForegroundColor Cyan
Write-Host "  http://$ClientId.$BaseDomain"
Write-Host "  http://phpmyadmin.$ClientId.$BaseDomain"
Write-Host "  http://mail.$ClientId.$BaseDomain"
