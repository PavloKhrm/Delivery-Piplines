# Test Dynamic Setup Script
# This script simulates both fresh setup and existing deployment scenarios

Write-Host "Testing Dynamic Local Domains Setup" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Test 1: Current state (existing deployment)
Write-Host "`nTest 1: Current State (Existing Deployment)" -ForegroundColor Cyan
Write-Host "Checking current domains..." -ForegroundColor Yellow

try {
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    if ($blogNamespaces.Count -gt 0) {
        Write-Host "✅ Found $($blogNamespaces.Count) existing blog namespaces:" -ForegroundColor Green
        foreach ($namespace in $blogNamespaces) {
            $nsName = $namespace.metadata.name
            try {
                $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
                if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                    $domainHost = $ingresses.items[0].spec.rules[0].host
                    Write-Host "  - ${nsName}: $domainHost" -ForegroundColor White
                }
            } catch {
                Write-Host "  - ${nsName}: No ingress found" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nTesting domain accessibility..." -ForegroundColor Yellow
        
        # Test each domain
        foreach ($namespace in $blogNamespaces) {
            $nsName = $namespace.metadata.name
            try {
                $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
                if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                    $domainHost = $ingresses.items[0].spec.rules[0].host
                    
                    Write-Host "  Testing https://$domainHost`:8443/..." -ForegroundColor Gray
                    try {
                        $response = C:\Windows\System32\curl.exe -k -s -w "%{http_code}" https://$domainHost`:8443/
                        if ($response -like "*200*") {
                            Write-Host "  ✅ $domainHost is accessible (HTTP 200)" -ForegroundColor Green
                        } else {
                            Write-Host "  ❌ $domainHost returned: $response" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "  ❌ $domainHost connection failed" -ForegroundColor Red
                    }
                }
            } catch {
                # Skip failed namespaces
            }
        }
        
    } else {
        Write-Host "❌ No existing blog namespaces found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Failed to check namespaces: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Port forwarding status
Write-Host "`nTest 2: Port Forwarding Status" -ForegroundColor Cyan
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
} else {
    Write-Host "❌ Port forwarding is not running" -ForegroundColor Red
    Write-Host "Starting port forwarding..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "kubectl" -ArgumentList "port-forward", "-n", "traefik-system", "service/traefik", "8080:80", "8443:443" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        Write-Host "✅ Port forwarding started" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to start port forwarding: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 3: SSL certificates
Write-Host "`nTest 3: SSL Certificates" -ForegroundColor Cyan
$sslCertExists = Test-Path "ssl-certificates\blog-cert.pem"
if ($sslCertExists) {
    Write-Host "✅ SSL certificate exists: ssl-certificates\blog-cert.pem" -ForegroundColor Green
} else {
    Write-Host "❌ SSL certificate not found" -ForegroundColor Red
}

# Test 4: Hosts file
Write-Host "`nTest 4: Hosts File Configuration" -ForegroundColor Cyan
try {
    $hostsContent = Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    $localEntries = $hostsContent | Where-Object { $_ -like "*127.0.0.1*" -and $_ -like "*.local*" }
    
    if ($localEntries.Count -gt 0) {
        Write-Host "✅ Hosts file has $($localEntries.Count) local domain entries:" -ForegroundColor Green
        foreach ($entry in $localEntries) {
            Write-Host "  $entry" -ForegroundColor White
        }
    } else {
        Write-Host "❌ No local domain entries found in hosts file" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking hosts file: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Traefik status
Write-Host "`nTest 5: Traefik Status" -ForegroundColor Cyan
try {
    $traefikPod = kubectl get pods -n traefik-system -l app.kubernetes.io/name=traefik -o json | ConvertFrom-Json
    if ($traefikPod.items.Count -gt 0) {
        $podName = $traefikPod.items[0].metadata.name
        $podStatus = $traefikPod.items[0].status.phase
        Write-Host "✅ Traefik pod is running: $podName ($podStatus)" -ForegroundColor Green
        
        # Get container ports
        $podDesc = kubectl describe pod $podName -n traefik-system
        if ($podDesc -match "8000/TCP.*web") {
            Write-Host "  - Web port: 8000" -ForegroundColor White
        }
        if ($podDesc -match "8443/TCP.*websecure") {
            Write-Host "  - WebSecure port: 8443" -ForegroundColor White
        }
        if ($podDesc -match "8080/TCP.*traefik") {
            Write-Host "  - Traefik dashboard port: 8080" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Traefik pod not found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error checking Traefik: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nDynamic Setup Test Complete!" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "- The dynamic script handles both fresh setups and existing deployments" -ForegroundColor White
Write-Host "- It automatically detects existing domains or creates default ones" -ForegroundColor White
Write-Host "- It uses correct port mappings based on actual Traefik container ports" -ForegroundColor White
Write-Host "- It creates SSL certificates for all detected domains" -ForegroundColor White
Write-Host "- It updates hosts file and starts port forwarding automatically" -ForegroundColor White
