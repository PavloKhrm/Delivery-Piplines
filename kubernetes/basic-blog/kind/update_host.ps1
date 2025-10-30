[CmdletBinding()]
param (
  [string]$IP,
  [string]$ClientId,
  [string]$BaseDomain
)

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