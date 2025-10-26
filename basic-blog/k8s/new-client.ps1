[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ClientId
)

# BaseDomain will now be read from the Helm chart's values.yaml
$ErrorActionPreference = 'Stop'
$ns = "client-$ClientId"
$chartPath = Join-Path $PSScriptRoot "charts/client-stack"
$envPath   = ".\env"

# -------------------------------
# Load environment variables (optional)
# -------------------------------
Write-Host "Checking for .env file..." -ForegroundColor Cyan

$envFile = Join-Path $envPath "$ClientId.env"
if (-not (Test-Path $envFile)) {
  $envFile = Join-Path $envPath "global.env"
}

if (Test-Path $envFile) {
  Write-Host "Loading environment from $envFile" -ForegroundColor Green
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^(?<key>[^#=]+)=(?<value>.+)$') {
      [Environment]::SetEnvironmentVariable($matches.key.Trim(), $matches.value.Trim())
    }
  }
} else {
  Write-Host "No .env file found. Falling back to values.yaml." -ForegroundColor Yellow
}

# -------------------------------
# Extract base domain, storage, timeout
# -------------------------------
$BaseDomain   = $env:BASE_DOMAIN
$StorageClass = $env:STORAGE_CLASS
$Timeout      = if ($env:TIMEOUT) { $env:TIMEOUT } else { "5m" }

# Fallback to values.yaml if baseDomain not set
if (-not $BaseDomain) {
  $baseDomainLine = Get-Content "$chartPath\values.yaml" | Select-String -SimpleMatch "baseDomain:"
  $BaseDomain = ($baseDomainLine -split ":")[1].Trim()
}

Write-Host "Using environment:"
Write-Host "  BASE_DOMAIN   = $BaseDomain"
Write-Host "  STORAGE_CLASS = $StorageClass"
Write-Host "  TIMEOUT       = $Timeout"
Write-Host ""

# -------------------------------
# Create namespace
# -------------------------------
Write-Host "Creating namespace $ns..." -ForegroundColor Cyan
kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - | Out-Null

# -------------------------------
# Helm deployment
# -------------------------------
Write-Host "Installing Helm release for $ClientId..." -ForegroundColor Cyan

try {
  helm upgrade --install $ClientId `
    $chartPath `
    --namespace $ns `
    --create-namespace `
    --set clientId=$ClientId `
    --set storageClassName=$StorageClass `
    --wait --atomic --timeout $Timeout
}
catch {
  Write-Host "Helm deployment failed for $ClientId. Cleaning up namespace..." -ForegroundColor Red
  kubectl delete namespace $ns -q
  exit 1
}

# -------------------------------
# Success output
# -------------------------------
Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
Write-Host "Access your services at:" -ForegroundColor Cyan
Write-Host "  Website:    http://$ClientId.$BaseDomain"
Write-Host "  phpMyAdmin: http://phpmyadmin.$ClientId.$BaseDomain"
Write-Host "  MailCrab:   http://mail.$ClientId.$BaseDomain"

# No more host file updates needed!

# We can read the baseDomain from the values file to provide the correct URLs
# $baseDomainLine = Get-Content ".\k8s\charts\client-stack\values.yaml" | Select-String -SimpleMatch "baseDomain:"
# $BaseDomain = ($baseDomainLine -split ":")[1].Trim()
#
# Write-Host "Done. Open:" -ForegroundColor Cyan
# Write-Host "  http://$ClientId.$BaseDomain"
# Write-Host "  http://phpmyadmin.$ClientId.$BaseDomain"
# Write-Host "  http://mail.$ClientId.$BaseDomain"