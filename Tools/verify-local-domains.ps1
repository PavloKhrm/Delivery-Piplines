# Verify Local Domains Are Working
# Simple script to test if local domains are accessible

Write-Host "Verifying Local Domains" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

# Test demo1.local
Write-Host "`nTesting demo1.local:8443..." -ForegroundColor Yellow
try {
    $response = C:\Windows\System32\curl.exe -k -s -w "%{http_code}" https://demo1.local:8443/
    if ($response -like "*200*") {
        Write-Host "✅ demo1.local:8443 is working!" -ForegroundColor Green
        $title = ($response | Select-String -Pattern '<title>(.*)</title>').Matches.Groups[1].Value
        Write-Host "   Title: $title" -ForegroundColor Cyan
    } else {
        Write-Host "❌ demo1.local:8443 failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ demo1.local:8443 connection failed" -ForegroundColor Red
}

# Test tech1.local
Write-Host "`nTesting tech1.local:8443..." -ForegroundColor Yellow
try {
    $response = C:\Windows\System32\curl.exe -k -s -w "%{http_code}" https://tech1.local:8443/
    if ($response -like "*200*") {
        Write-Host "✅ tech1.local:8443 is working!" -ForegroundColor Green
        $title = ($response | Select-String -Pattern '<title>(.*)</title>').Matches.Groups[1].Value
        Write-Host "   Title: $title" -ForegroundColor Cyan
    } else {
        Write-Host "❌ tech1.local:8443 failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ tech1.local:8443 connection failed" -ForegroundColor Red
}

# Check port forwarding
Write-Host "`nChecking port forwarding..." -ForegroundColor Yellow
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
}

# Check hosts file
Write-Host "`nChecking hosts file..." -ForegroundColor Yellow
$hostsContent = Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
$localEntries = $hostsContent | Where-Object { $_ -like "*127.0.0.1*" -and $_ -like "*.local*" }

if ($localEntries.Count -gt 0) {
    Write-Host "✅ Hosts file has $($localEntries.Count) local domain entries:" -ForegroundColor Green
    foreach ($entry in $localEntries) {
        Write-Host "   $entry" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ No local domain entries found in hosts file" -ForegroundColor Red
}

Write-Host "`nVerification Complete!" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
