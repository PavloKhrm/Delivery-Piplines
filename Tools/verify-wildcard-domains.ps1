# Verify Wildcard Domains Are Working
# Simple script to test if wildcard domains are accessible

Write-Host "Verifying Wildcard Domains" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green

# Read port information from the port-forward-info.json file
$portInfo = @{}
if (Test-Path ".\port-forward-info.json") {
    try {
        $portInfo = Get-Content ".\port-forward-info.json" | ConvertFrom-Json
        $httpPort = $portInfo.httpPort
        $httpsPort = $portInfo.httpsPort
        Write-Host "Using ports from port-forward-info.json: HTTP=$httpPort, HTTPS=$httpsPort" -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to read port info, using defaults: HTTP=9081, HTTPS=9444" -ForegroundColor Yellow
        $httpPort = 9081
        $httpsPort = 9444
    }
} else {
    Write-Host "No port info file found, using defaults: HTTP=9081, HTTPS=9444" -ForegroundColor Yellow
    $httpPort = 9081
    $httpsPort = 9444
}

# Test wildcard domains
$domains = @("meow-tech.emit-it.local", "please-work.emit-it.local")

Write-Host "`nTesting Wildcard Domains..." -ForegroundColor Cyan
Write-Host "Base domain: emit-it.local" -ForegroundColor Gray
Write-Host "Wildcard certificate: *.emit-it.local" -ForegroundColor Gray

foreach ($domain in $domains) {
    Write-Host "`nTesting $domain..." -ForegroundColor Yellow
    
    # Test HTTPS
    try {
        $response = C:\Windows\System32\curl.exe -k -s -w "%{http_code}" "https://$domain`:$httpsPort/"
        if ($response -like "*200*") {
            Write-Host "✅ HTTPS: $domain is accessible (HTTP 200)" -ForegroundColor Green
            $title = ($response | Select-String -Pattern '<title>(.*)</title>').Matches.Groups[1].Value
            Write-Host "   Title: $title" -ForegroundColor Cyan
        } else {
            Write-Host "❌ HTTPS: $domain failed - $response" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ HTTPS: $domain connection failed" -ForegroundColor Red
    }
    
    # Test HTTP (should redirect to HTTPS)
    try {
        $response = C:\Windows\System32\curl.exe -s -w "%{http_code}" "http://$domain`:$httpPort/"
        if ($response -like "*301*" -or $response -like "*302*") {
            Write-Host "✅ HTTP: $domain redirects to HTTPS (expected)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ HTTP: $domain response: $response" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ HTTP: $domain connection failed" -ForegroundColor Red
    }
}

# Check port forwarding
Write-Host "`nChecking port forwarding..." -ForegroundColor Cyan
$kubectlProcesses = Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Where-Object { 
    try {
        $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
        $commandLine -and $commandLine -like "*port-forward*"
    } catch {
        $false
    }
}

if ($kubectlProcesses.Count -gt 0) {
    Write-Host "✅ Port forwarding is running ($($kubectlProcesses.Count) processes)" -ForegroundColor Green
    foreach ($process in $kubectlProcesses) {
        try {
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            Write-Host "   Command: $commandLine" -ForegroundColor Gray
        } catch {
            Write-Host "   Process ID: $($process.Id)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "❌ Port forwarding is not running" -ForegroundColor Red
}

# Check hosts file
Write-Host "`nChecking hosts file..." -ForegroundColor Cyan
try {
    $hostsContent = Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    $emitItEntries = $hostsContent | Where-Object { $_ -like "*emit-it.local*" }
    
    if ($emitItEntries.Count -gt 0) {
        Write-Host "✅ Found $($emitItEntries.Count) emit-it.local entries in hosts file:" -ForegroundColor Green
        foreach ($entry in $emitItEntries) {
            Write-Host "   $entry" -ForegroundColor White
        }
    } else {
        Write-Host "❌ No emit-it.local entries found in hosts file" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking hosts file: $($_.Exception.Message)" -ForegroundColor Red
}

# Check SSL certificates
Write-Host "`nChecking SSL certificates..." -ForegroundColor Cyan
$wildcardCertExists = Test-Path "ssl-certificates\wildcard-emit-it-cert.pem"
if ($wildcardCertExists) {
    Write-Host "✅ Wildcard SSL certificate exists: ssl-certificates\wildcard-emit-it-cert.pem" -ForegroundColor Green
} else {
    Write-Host "❌ Wildcard SSL certificate not found" -ForegroundColor Red
}

# Check Kubernetes secrets
Write-Host "`nChecking Kubernetes secrets..." -ForegroundColor Cyan
try {
    $secrets = kubectl get secrets -n traefik-system | Select-String "wildcard-emit-it-ssl-cert"
    if ($secrets) {
        Write-Host "✅ Wildcard SSL secret exists in traefik-system namespace" -ForegroundColor Green
    } else {
        Write-Host "❌ Wildcard SSL secret not found in traefik-system namespace" -ForegroundColor Red
    }
    
    $namespaceSecrets = kubectl get secrets --all-namespaces | Select-String "wildcard-emit-it-tls"
    if ($namespaceSecrets) {
        Write-Host "✅ Wildcard TLS secrets exist in blog namespaces" -ForegroundColor Green
        foreach ($secret in $namespaceSecrets) {
            Write-Host "   $secret" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ Wildcard TLS secrets not found in blog namespaces" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking Kubernetes secrets: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nWildcard Domain Verification Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "- Wildcard domain *.emit-it.local covers all subdomains" -ForegroundColor White
Write-Host "- Single SSL certificate works for all subdomains" -ForegroundColor White
Write-Host "- Dynamic port selection avoids conflicts" -ForegroundColor White
Write-Host "- Easy to add new subdomains (just update hosts file)" -ForegroundColor White
Write-Host "- Perfect for team development and scaling" -ForegroundColor White

Write-Host "`nAccess URLs:" -ForegroundColor Cyan
foreach ($domain in $domains) {
    Write-Host "  https://$domain`:$httpsPort/" -ForegroundColor White
}
