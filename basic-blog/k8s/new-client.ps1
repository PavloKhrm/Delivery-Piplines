[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ClientId
)

# BaseDomain will now be read from the Helm chart's values.yaml
$ErrorActionPreference = 'Stop'
$ns = "client-$ClientId"
$chartPath = ".\k8s\charts\client-stack"

Write-Host "Creating namespace $ns..." -ForegroundColor Cyan
kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "Installing client stack for $ClientId..." -ForegroundColor Cyan
# The script now relies on the baseDomain from values.yaml
helm upgrade --install $ClientId `
  $chartPath `
  --namespace $ns `
  --create-namespace `
  --set clientId=$ClientId `
  --wait --timeout 5m

# No more host file updates needed!

# We can read the baseDomain from the values file to provide the correct URLs
$baseDomainLine = Get-Content ".\k8s\charts\client-stack\values.yaml" | Select-String -SimpleMatch "baseDomain:"
$BaseDomain = ($baseDomainLine -split ":")[1].Trim()

Write-Host "Done. Open:" -ForegroundColor Cyan
Write-Host "  http://$ClientId.$BaseDomain"
Write-Host "  http://phpmyadmin.$ClientId.$BaseDomain"
Write-Host "  http://mail.$ClientId.$BaseDomain"