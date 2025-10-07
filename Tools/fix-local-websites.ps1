# Simple Fix for Local Website Domains
# This script makes your local blog domains work

Write-Host "Fixing Local Blog Websites" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

# Step 1: Stop any existing port forwarding
Write-Host "`n1. Stopping existing port forwarding..." -ForegroundColor Yellow
Get-Job | Stop-Job -ErrorAction SilentlyContinue
Get-Job | Remove-Job -ErrorAction SilentlyContinue

# Step 2: Start Traefik port forwarding
Write-Host "2. Starting Traefik port forwarding..." -ForegroundColor Yellow
Start-Job -Name "traefik-forward" -ScriptBlock { 
    kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443 
}

# Wait for port forwarding to start
Start-Sleep -Seconds 5

# Step 3: Get all your blog domains
Write-Host "3. Getting your blog domains..." -ForegroundColor Yellow
$ingresses = kubectl get ingress -A -o json | ConvertFrom-Json
$domains = @()

foreach ($ingress in $ingresses.items) {
    if ($ingress.metadata.namespace -like "blog-*") {
        $host = $ingress.spec.rules[0].host
        $domains += $host
        Write-Host "Found domain: $host" -ForegroundColor Cyan
    }
}

# Step 4: Update Windows hosts file
Write-Host "`n4. Updating Windows hosts file..." -ForegroundColor Yellow
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

try {
    # Read current hosts file
    $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
    
    # Remove old blog entries
    $filteredHosts = $currentHosts | Where-Object { 
        $_ -notmatch "^127\.0\.0\.1.*\.local.*$" 
    }
    
    # Add new entries
    $newEntries = @()
    foreach ($domain in $domains) {
        $newEntries += "127.0.0.1 $domain"
    }
    
    $updatedHosts = $filteredHosts + "" + "# Local blog domains" + $newEntries
    $updatedHosts | Out-File -FilePath $hostsFile -Encoding ASCII
    
    Write-Host "Hosts file updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "Could not update hosts file automatically. Please add these lines manually to C:\Windows\System32\drivers\etc\hosts:" -ForegroundColor Red
    foreach ($domain in $domains) {
        Write-Host "127.0.0.1 $domain" -ForegroundColor White
    }
}

# Step 5: Show results
Write-Host "`n5. Your websites are now accessible at:" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

foreach ($domain in $domains) {
    Write-Host "https://$domain`:8443/" -ForegroundColor Cyan
}

Write-Host "`nIMPORTANT:" -ForegroundColor Yellow
Write-Host "- Your browser will show a security warning (this is normal for local domains)" -ForegroundColor White
Write-Host "- Click 'Advanced' then 'Proceed to website' to access your blogs" -ForegroundColor White
Write-Host "- If domains don't work, restart your browser after updating hosts file" -ForegroundColor White

Write-Host "`nDone! Your local blog websites should now work." -ForegroundColor Green
