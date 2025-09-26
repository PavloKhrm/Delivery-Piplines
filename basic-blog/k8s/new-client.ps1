[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ClientId,
  [Parameter(Mandatory=$false)]
  [string]$BaseDomain
)

if (-not $BaseDomain) {
  try {
    $valuesPath = ".\k8s\charts\client-stack\values.yaml"
    $baseDomainLine = Get-Content $valuesPath | Select-String -SimpleMatch "baseDomain:"
    $BaseDomain = ($baseDomainLine -split ":")[1].Trim()
    Write-Host "BaseDomain not specified, using '$BaseDomain' from Helm values." -ForegroundColor Cyan
  } catch {
    Write-Error "Could not automatically determine BaseDomain. Please specify it with the -BaseDomain parameter."
    exit 1
  }
}

$ErrorActionPreference = 'Stop'
$ns = "client-$ClientId"
$chartPath = ".\k8s\charts\client-stack"

try {
  kubectl get nodes 1>$null 2>$null
} catch {
  Write-Host "Starting minikube..." -ForegroundColor Cyan
  minikube start --cpus 4 --memory 5500 --driver=docker
}

Write-Host "Installing/repairing Traefik..." -ForegroundColor Cyan
helm repo add traefik https://traefik.github.io/charts | Out-Null
helm repo update | Out-Null
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace `
  --set service.type=LoadBalancer `
  --set ingressClass.enabled=true `
  --set ingressClass.name=traefik `
  --set ingressClass.isDefaultClass=false | Out-Null

kubectl -n traefik rollout status deploy/traefik --timeout=180s

$traefikIp = ""
for ($i=0; $i -lt 20 -and -not $traefikIp; $i++) {
  $traefikIp = kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
  if (-not $traefikIp) {
      if ($IsWindows) {
          Write-Warning "Traefik LB IP not found. Start 'minikube tunnel' in a separate Administrator terminal, then press Enter."
      } else {
          Write-Warning "Traefik LB IP not found. Run 'minikube tunnel' in a separate terminal (you may need sudo), then press Enter."
      }
      Read-Host | Out-Null
  }
}
if (-not $traefikIp) { throw "Traefik LB IP still not available. Ensure 'minikube tunnel' is running." }

kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - | Out-Null

helm upgrade --install $ClientId `
  $chartPath `
  --namespace $ns `
  --create-namespace `
  --set clientId=$ClientId `
  --set baseDomain=$BaseDomain `
  --wait --timeout 5m

$ingList = kubectl -n $ns get ingress -o name 2>$null
if ($ingList) {
  $ingList -split "`n" | ForEach-Object {
    if ($_){ kubectl -n $ns annotate $_ kubernetes.io/ingress.class=traefik --overwrite | Out-Null }
  }
}

# Call the correct helper script to update the hosts file
if ($IsWindows) {
    powershell.exe -ExecutionPolicy Bypass -File ".\k8s\update-hosts.ps1" -IP $traefikIp -ClientId $ClientId -BaseDomain $BaseDomain
} else {
    bash ".\k8s\update-hosts.sh" $traefikIp $ClientId $BaseDomain
}

Write-Host "Done. Open:" -ForegroundColor Cyan
Write-Host "  http://$ClientId.$BaseDomain"
Write-Host "  http://phpmyadmin.$ClientId.$BaseDomain"
Write-Host "  http://mail.$ClientId.$BaseDomain"