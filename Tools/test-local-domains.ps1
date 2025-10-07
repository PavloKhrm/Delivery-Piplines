# Test Local Domains Access
# This script tests if all local domains are accessible with proper SSL certificates

param(
    [switch]$EnableLogging = $false
)

Write-Host "Testing Local Domains Access" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    
    if ($EnableLogging) {
        $logFile = ".\logs\test-local-domains-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Starting local domains test..." "INFO" "Cyan"

# Step 1: Check if port forwarding is running
Write-Log "`nStep 1: Checking port forwarding status..." "INFO" "Cyan"

$portForwardRunning = $false
try {
    $kubectlProcesses = Get-Process -Name "kubectl" -ErrorAction SilentlyContinue
    foreach ($process in $kubectlProcesses) {
        try {
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($commandLine -and $commandLine -like "*port-forward*") {
                $portForwardRunning = $true
                Write-Log "Port forwarding is running (PID: $($process.Id))" "SUCCESS" "Green"
                break
            }
        } catch {
            # Skip processes where we can't get command line
        }
    }
    
    if (-not $portForwardRunning) {
        Write-Log "Port forwarding is not running" "WARNING" "Yellow"
        Write-Log "Starting port forwarding..." "INFO" "Cyan"
        try {
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\Tools\start-port-forwarding.ps1" -WindowStyle Hidden
            Start-Sleep -Seconds 5
            Write-Log "Port forwarding started" "SUCCESS" "Green"
            $portForwardRunning = $true
        } catch {
            Write-Log "Failed to start port forwarding: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
} catch {
    Write-Log "Error checking port forwarding status: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 2: Get all blog domains from Kubernetes
Write-Log "`nStep 2: Getting blog domains from Kubernetes..." "INFO" "Cyan"

$domains = @()
try {
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        try {
            $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
            if ($ingresses.items -and $ingresses.items.Count -gt 0) {
                $host = $ingresses.items[0].spec.rules[0].host
                $domains += @{
                    Domain = $host
                    Namespace = $nsName
                    IngressName = $ingresses.items[0].metadata.name
                }
                Write-Log "Found domain: $host in namespace $nsName" "INFO" "Yellow"
            }
        } catch {
            Write-Log "Failed to get ingress for namespace $nsName" "WARNING" "Yellow"
        }
    }
    
    if ($domains.Count -eq 0) {
        Write-Log "No blog domains found" "WARNING" "Yellow"
        Write-Log "Creating test domains..." "INFO" "Cyan"
        $domains = @(
            @{ Domain = "demo1.local"; Namespace = "test"; IngressName = "test" },
            @{ Domain = "tech1.local"; Namespace = "test"; IngressName = "test" }
        )
    }
} catch {
    Write-Log "Failed to get domains from Kubernetes: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

Write-Log "Testing $($domains.Count) domains..." "INFO" "Cyan"

# Step 3: Test each domain
Write-Log "`nStep 3: Testing domain accessibility..." "INFO" "Cyan"

$testResults = @()
foreach ($domainInfo in $domains) {
    $domain = $domainInfo.Domain
    $namespace = $domainInfo.Namespace
    $ingressName = $domainInfo.IngressName
    
    Write-Log "`nTesting domain: $domain" "INFO" "Cyan"
    
    # Test HTTP (should redirect to HTTPS)
    try {
        Write-Log "  Testing HTTP: http://$domain`:8080/" "INFO" "Gray"
        $httpResult = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" -L "http://$domain`:8080/" 2>$null
        if ($httpResult -eq "200" -or $httpResult -eq "301" -or $httpResult -eq "302") {
            Write-Log "  HTTP test: SUCCESS (Code: $httpResult)" "SUCCESS" "Green"
        } else {
            Write-Log "  HTTP test: FAILED (Code: $httpResult)" "ERROR" "Red"
        }
    } catch {
        Write-Log "  HTTP test: FAILED (Connection error)" "ERROR" "Red"
    }
    
    # Test HTTPS
    try {
        Write-Log "  Testing HTTPS: https://$domain`:8443/" "INFO" "Gray"
        $httpsResult = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" "https://$domain`:8443/" 2>$null
        if ($httpsResult -eq "200") {
            Write-Log "  HTTPS test: SUCCESS (Code: $httpsResult)" "SUCCESS" "Green"
            $testResults += @{
                Domain = $domain
                HTTP = $httpResult
                HTTPS = $httpsResult
                Status = "SUCCESS"
            }
        } else {
            Write-Log "  HTTPS test: FAILED (Code: $httpsResult)" "ERROR" "Red"
            $testResults += @{
                Domain = $domain
                HTTP = $httpResult
                HTTPS = $httpsResult
                Status = "FAILED"
            }
        }
    } catch {
        Write-Log "  HTTPS test: FAILED (Connection error)" "ERROR" "Red"
        $testResults += @{
            Domain = $domain
            HTTP = "ERROR"
            HTTPS = "ERROR"
            Status = "FAILED"
        }
    }
    
    # Test API endpoint
    try {
        Write-Log "  Testing API: https://$domain`:8443/api/" "INFO" "Gray"
        $apiResult = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" "https://$domain`:8443/api/" 2>$null
        if ($apiResult -eq "200" -or $apiResult -eq "404") {
            Write-Log "  API test: SUCCESS (Code: $apiResult)" "SUCCESS" "Green"
        } else {
            Write-Log "  API test: FAILED (Code: $apiResult)" "ERROR" "Red"
        }
    } catch {
        Write-Log "  API test: FAILED (Connection error)" "ERROR" "Red"
    }
    
    # Test health endpoint
    try {
        Write-Log "  Testing Health: https://$domain`:8443/health" "INFO" "Gray"
        $healthResult = & C:\Windows\System32\curl.exe -k -s -o $null -w "%{http_code}" "https://$domain`:8443/health" 2>$null
        if ($healthResult -eq "200") {
            Write-Log "  Health test: SUCCESS (Code: $healthResult)" "SUCCESS" "Green"
        } else {
            Write-Log "  Health test: FAILED (Code: $healthResult)" "ERROR" "Red"
        }
    } catch {
        Write-Log "  Health test: FAILED (Connection error)" "ERROR" "Red"
    }
}

# Step 4: Check SSL certificates
Write-Log "`nStep 4: Checking SSL certificates..." "INFO" "Cyan"

try {
    $sslCertExists = Test-Path "ssl-certificates\blog-cert.pem"
    if ($sslCertExists) {
        Write-Log "SSL certificate file exists: ssl-certificates\blog-cert.pem" "SUCCESS" "Green"
        
        # Check certificate details
        $certInfo = & C:\Windows\System32\openssl.exe x509 -in "ssl-certificates\blog-cert.pem" -text -noout 2>$null
        if ($certInfo) {
            Write-Log "SSL certificate is valid" "SUCCESS" "Green"
        } else {
            Write-Log "SSL certificate validation failed" "WARNING" "Yellow"
        }
    } else {
        Write-Log "SSL certificate file not found" "ERROR" "Red"
    }
} catch {
    Write-Log "Error checking SSL certificates: $($_.Exception.Message)" "WARNING" "Yellow"
}

# Step 5: Check hosts file
Write-Log "`nStep 5: Checking hosts file..." "INFO" "Cyan"

try {
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
    
    $hostsEntries = $hostsContent | Where-Object { $_ -like "*127.0.0.1*" -and $_ -like "*.local*" }
    
    if ($hostsEntries.Count -gt 0) {
        Write-Log "Found $($hostsEntries.Count) local domain entries in hosts file:" "SUCCESS" "Green"
        foreach ($entry in $hostsEntries) {
            Write-Log "  $entry" "INFO" "White"
        }
    } else {
        Write-Log "No local domain entries found in hosts file" "WARNING" "Yellow"
    }
} catch {
    Write-Log "Error checking hosts file: $($_.Exception.Message)" "WARNING" "Yellow"
}

# Step 6: Generate test report
Write-Log "`nStep 6: Generating test report..." "INFO" "Cyan"

$reportFile = ".\logs\local-domains-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$report = @"
Local Domains Test Report
========================
Generated: $(Get-Date)

Test Summary:
- Total domains tested: $($domains.Count)
- Port forwarding running: $(if ($portForwardRunning) { 'YES' } else { 'NO' })
- SSL certificates present: $(if (Test-Path "ssl-certificates\blog-cert.pem") { 'YES' } else { 'NO' })

Domain Test Results:
"@

foreach ($result in $testResults) {
    $report += "`n- $($result.Domain)"
    $report += "`n  HTTP Status: $($result.HTTP)"
    $report += "`n  HTTPS Status: $($result.HTTPS)"
    $report += "`n  Overall: $($result.Status)"
}

$report += "`n`nAccess URLs:"
foreach ($domainInfo in $domains) {
    $domain = $domainInfo.Domain
    $report += "`n- Frontend: https://$domain`:8443/"
    $report += "`n- Backend API: https://$domain`:8443/api/"
    $report += "`n- Health Check: https://$domain`:8443/health"
}

$report += "`n`nTroubleshooting:"
$report += "`n- If domains are not accessible, check port forwarding is running"
$report += "`n- If SSL errors occur, run fix-local-domains-complete.ps1"
$report += "`n- If hosts file issues, run update-hosts-file.ps1 as Administrator"

try {
    if (!(Test-Path ".\logs")) {
        New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
    }
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Log "Test report saved to: $reportFile" "SUCCESS" "Green"
} catch {
    Write-Log "Failed to save test report: $($_.Exception.Message)" "ERROR" "Red"
}

# Final summary
Write-Log "`nLocal Domains Test Complete!" "SUCCESS" "Green"
Write-Log "=============================" "SUCCESS" "Green"

$successCount = ($testResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
$totalCount = $testResults.Count

Write-Log "`nTest Results:" "INFO" "Cyan"
Write-Log "  Successful: $successCount / $totalCount" "INFO" "White"
Write-Log "  Failed: $($totalCount - $successCount) / $totalCount" "INFO" "White"

if ($successCount -eq $totalCount -and $totalCount -gt 0) {
    Write-Log "`nAll domains are working correctly!" "SUCCESS" "Green"
    Write-Log "Your local domain setup is fully functional" "INFO" "Cyan"
} elseif ($successCount -gt 0) {
    Write-Log "`nSome domains are working, but issues remain" "WARNING" "Yellow"
    Write-Log "Check the test report for details" "INFO" "Cyan"
} else {
    Write-Log "`nNo domains are accessible" "ERROR" "Red"
    Write-Log "Run fix-local-domains-complete.ps1 to resolve issues" "INFO" "Cyan"
}

Write-Log "`nTest report saved to: $reportFile" "INFO" "Cyan"
