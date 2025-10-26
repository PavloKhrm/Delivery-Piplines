[CmdletBinding()]
param (
  [string]$IP,
  [string]$ClientId,
  [string]$BaseDomain
)

# ---------------------------------
# Load environment variables (optional)
# ---------------------------------
$envPath = ".\k8s\env"
$envFile = Join-Path $envPath "$ClientId.env"

if (-not (Test-Path $envFile)) {
  $envFile = Join-Path $envPath "global.env"
}

if (Test-Path $envFile) {
  Write-Host "Loading environment from $envFile" -ForegroundColor Cyan
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^(?<key>[^#=]+)=(?<value>.+)$') {
      [Environment]::SetEnvironmentVariable($matches.key.Trim(), $matches.value.Trim())
    }
  }
  $BaseDomain = $env:BASE_DOMAIN
} else {
  Write-Host "No .env file found. Falling back to values.yaml." -ForegroundColor Yellow
  $chartPath = ".\k8s\charts\client-stack"
  $baseDomainLine = Get-Content "$chartPath\values.yaml" | Select-String -SimpleMatch "baseDomain:"
  $BaseDomain = ($baseDomainLine -split ":")[1].Trim()
}

# ---------------------------------
# Update hosts file
# ---------------------------------
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$lines = @(
  "$IP $ClientId.$BaseDomain",
  "$IP phpmyadmin.$ClientId.$BaseDomain",
  "$IP mail.$ClientId.$BaseDomain"
)

# Administrator check for Windows
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p  = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run PowerShell as Administrator to auto-update hosts. Add these lines manually:"
    $lines | ForEach-Object { Write-Host $_ }
    exit
}

if (Test-Path $hostsPath) {
  $existing = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
} else {
  $existing = @()
}

$toAdd = $lines | Where-Object { $existing -notcontains $_ }
if ($toAdd) {
  Add-Content -Path $hostsPath -Value ($toAdd -join "`r`n")
  Write-Host "Hosts file updated." -ForegroundColor Green
} else {
  Write-Host "Hosts file already contains client entries." -ForegroundColor DarkGreen
}

Write-Host ""
Write-Host "Accessible URLs:" -ForegroundColor Cyan
Write-Host "  http://$ClientId.$BaseDomain"
Write-Host "  http://phpmyadmin.$ClientId.$BaseDomain"
Write-Host "  http://mail.$ClientId.$BaseDomain"