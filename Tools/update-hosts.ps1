# Update hosts file for blog domains
# Run this script as Administrator

$ErrorActionPreference = "Stop"

Write-Host "Adding blog domains to hosts file..." -ForegroundColor Green

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$domains = @(
    "127.0.0.1 demo.dev.local",
    "127.0.0.1 mycomponay.local", 
    "127.0.0.1 tech.local"
)

# Check if domains already exist
$existingContent = Get-Content $hostsFile
$needsUpdate = $false

foreach ($domain in $domains) {
    if ($existingContent -notcontains $domain) {
        $needsUpdate = $true
        break
    }
}

if ($needsUpdate) {
    Write-Host "Adding domains to hosts file..." -ForegroundColor Yellow
    foreach ($domain in $domains) {
        Add-Content -Path $hostsFile -Value $domain
        Write-Host "Added: $domain" -ForegroundColor Green
    }
    Write-Host "Hosts file updated successfully!" -ForegroundColor Green
} else {
    Write-Host "Domains already exist in hosts file." -ForegroundColor Yellow
}

Write-Host "`nBlog Access URLs:" -ForegroundColor Cyan
Write-Host "Demo Blog: http://demo.dev.local:8080" -ForegroundColor White
Write-Host "My Company Blog: http://mycomponay.local:8080" -ForegroundColor White  
Write-Host "Tech Blog: http://tech.local:8080" -ForegroundColor White
Write-Host "`nDashboard: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor White