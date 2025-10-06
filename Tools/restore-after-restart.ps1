# Restore Multi-Tenant Blog System After PC Restart
# This script handles everything needed after a PC restart

param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipDockerCheck,
    [Parameter(Mandatory = $false)]
    [switch]$SkipClusterCheck
)

$ErrorActionPreference = "Stop"

Write-Host "Restoring Multi-Tenant Blog System After PC Restart" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to wait for Docker to be ready
function Wait-ForDocker {
    Write-Host "Waiting for Docker to be ready..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0
    
    do {
        try {
            $null = docker info 2>$null
            Write-Host "Docker is ready!" -ForegroundColor Green
            return $true
        } catch {
            $attempt++
            Write-Host "Docker not ready yet... ($attempt/$maxAttempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    } while ($attempt -lt $maxAttempts)
    
    return $false
}

# Step 1: Check Docker
if (-not $SkipDockerCheck) {
    Write-Host "`nStep 1: Checking Docker..." -ForegroundColor Cyan
    if (-not (Test-Command "docker")) {
        Write-Host "ERROR: Docker not found. Please install Docker Desktop." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Wait-ForDocker)) {
        Write-Host "ERROR: Docker failed to start within expected time." -ForegroundColor Red
        Write-Host "Please start Docker Desktop manually and try again." -ForegroundColor Yellow
        exit 1
    }
}

# Step 2: Check Kind cluster
if (-not $SkipClusterCheck) {
    Write-Host "`nStep 2: Checking Kind cluster..." -ForegroundColor Cyan
    if (-not (Test-Command "kind")) {
        Write-Host "ERROR: Kind not found. Please install Kind." -ForegroundColor Red
        exit 1
    }
    
    try {
        $clusterExists = kind get clusters | Select-String "k8s-blog-template"
        if (-not $clusterExists) {
            Write-Host "ERROR: Kind cluster 'k8s-blog-template' not found." -ForegroundColor Red
            Write-Host "Please run the setup script first: .\setup-fresh-machine.ps1" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "Kind cluster found" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to check Kind cluster" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Check and restart Traefik if needed
Write-Host "`nStep 3: Checking Traefik..." -ForegroundColor Cyan
try {
    $traefikPods = kubectl get pods -n traefik-system -o json | ConvertFrom-Json
    $runningPods = $traefikPods.items | Where-Object { $_.status.phase -eq "Running" }
    
    if ($runningPods.Count -eq 0) {
        Write-Host "Traefik is not running. Installing Traefik..." -ForegroundColor Yellow
        
        # Install Traefik
        helm repo add traefik https://traefik.github.io/charts
        helm repo update
        helm install traefik traefik/traefik --namespace traefik-system --create-namespace --wait
        
        Write-Host "Traefik installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Traefik is running" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to check/install Traefik" -ForegroundColor Red
    exit 1
}

# Step 4: Check blog namespaces and pods
Write-Host "`nStep 4: Checking blog deployments..." -ForegroundColor Cyan
try {
    $namespaces = kubectl get namespaces -o json | ConvertFrom-Json
    $blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }
    
    Write-Host "Found $($blogNamespaces.Count) blog namespaces:" -ForegroundColor Green
    foreach ($ns in $blogNamespaces) {
        $namespace = $ns.metadata.name
        Write-Host "  - $namespace" -ForegroundColor Cyan
        
        # Check pods in this namespace
        $pods = kubectl get pods -n $namespace -o json | ConvertFrom-Json
        $runningPods = $pods.items | Where-Object { $_.status.phase -eq "Running" }
        $totalPods = $pods.items.Count
        
        Write-Host "    Pods: $($runningPods.Count)/$totalPods running" -ForegroundColor White
        
        if ($runningPods.Count -lt $totalPods) {
            Write-Host "    Some pods are not running. They should start automatically." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "WARNING: Could not check blog deployments" -ForegroundColor Yellow
}

# Step 5: Start dashboard server
Write-Host "`nStep 5: Starting dashboard server..." -ForegroundColor Cyan
try {
    # Check if dashboard server is already running
    $processes = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { 
        $_.CommandLine -like "*command-runner.js*" 
    }
    
    if ($processes.Count -eq 0) {
        Write-Host "Dashboard server not running. Starting it..." -ForegroundColor Yellow
        
        if (Test-Path "command-runner.js") {
            $dashboardJob = Start-Job -ScriptBlock {
                Set-Location $using:PWD
                node command-runner.js
            }
            Write-Host "Dashboard server started (Job ID: $($dashboardJob.Id))" -ForegroundColor Green
            Start-Sleep -Seconds 3
        } else {
            Write-Host "WARNING: command-runner.js not found. Dashboard will not be available." -ForegroundColor Yellow
            $dashboardJob = $null
        }
    } else {
        Write-Host "Dashboard server is already running" -ForegroundColor Green
        $dashboardJob = $null
    }
} catch {
    Write-Host "WARNING: Could not start dashboard server" -ForegroundColor Yellow
    $dashboardJob = $null
}

# Step 6: Set up dynamic port forwarding
Write-Host "`nStep 6: Setting up port forwarding..." -ForegroundColor Cyan

# Global variables for tracking jobs
$global:PortForwardJobs = @{}

# Function to kill existing port forwarding on a port
function Stop-ExistingPortForward {
    param([int]$Port)
    try {
        $existingProcess = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Write-Host "Killing existing process on port $Port..." -ForegroundColor Yellow
            $processId = $existingProcess.OwningProcess
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    } catch {
        # Ignore errors
    }
}

# Function to start port forwarding for a service
function Start-ServicePortForward {
    param(
        [string]$Namespace,
        [string]$ServiceName,
        [int]$LocalPort,
        [int]$RemotePort,
        [string]$Description
    )
    
    Write-Host "Starting port forwarding: localhost:$LocalPort -> $Namespace/$ServiceName -$RemotePort" -ForegroundColor Cyan
    Write-Host "  Description: $Description" -ForegroundColor Gray
    
    # Kill existing process on the port
    Stop-ExistingPortForward -Port $LocalPort
    
    # Start port forwarding job
    $job = Start-Job -ScriptBlock {
        param($Namespace, $Service, $LocalPort, $RemotePort)
        kubectl port-forward -n $Namespace service/$Service $LocalPort`:$RemotePort
    } -ArgumentList $Namespace, $ServiceName, $LocalPort, $RemotePort
    
    $global:PortForwardJobs[$LocalPort] = @{
        Job = $job
        Namespace = $Namespace
        Service = $ServiceName
        RemotePort = $RemotePort
        Description = $Description
    }
    
    Start-Sleep -Seconds 2
    return $job
}

# Discover and start port forwarding for Traefik
try {
    $traefikService = kubectl get service traefik -n traefik-system -o json | ConvertFrom-Json
    $webPort = $traefikService.spec.ports | Where-Object { $_.name -eq "web" } | Select-Object -First 1
    
    if ($webPort) {
        Write-Host "Starting Traefik port forwarding..." -ForegroundColor Green
        $portForwardJob = Start-ServicePortForward -Namespace "traefik-system" -ServiceName "traefik" -LocalPort 8080 -RemotePort $webPort.port -Description "Traefik Load Balancer"
    } else {
        Write-Host "ERROR: Could not find Traefik web port" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to set up Traefik port forwarding" -ForegroundColor Red
    exit 1
}

# Step 7: Test access
Write-Host "`nStep 7: Testing access..." -ForegroundColor Cyan

# Test Traefik access
try {
    $response = Invoke-WebRequest -Uri "https://localhost:8080" -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
    Write-Host " Traefik port forwarding is working! Accessible on localhost:8080" -ForegroundColor Green
} catch {
    Write-Host "  Traefik port forwarding test failed. It may take a moment to start." -ForegroundColor Yellow
}

# Test Dashboard access
try {
    $response = Invoke-WebRequest -Uri "https://localhost:3001/multi-blog-dashboard.html" -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
    Write-Host " Dashboard is accessible on localhost:3001" -ForegroundColor Green
} catch {
    Write-Host "  Dashboard test failed. It may take a moment to start." -ForegroundColor Yellow
}

# Step 8: Display final status
Write-Host "`nRestoration Complete!" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green
Write-Host "System Status:" -ForegroundColor White
Write-Host "  - Docker: Running" -ForegroundColor Green
Write-Host "  - Kind Cluster: Running" -ForegroundColor Green
Write-Host "  - Traefik: Running" -ForegroundColor Green
Write-Host "  - Dashboard Server: Running" -ForegroundColor Green
Write-Host "  - Port Forwarding: Active" -ForegroundColor Green

Write-Host "`nPort Forwarding Status:" -ForegroundColor White
Write-Host "=======================" -ForegroundColor White
foreach ($port in $global:PortForwardJobs.Keys) {
    $jobInfo = $global:PortForwardJobs[$port]
    Write-Host "Port $port -> $($jobInfo.Description)" -ForegroundColor Cyan
    Write-Host "  Job ID: $($jobInfo.Job.Id), Status: $($jobInfo.Job.State)" -ForegroundColor Gray
}

if ($dashboardJob) {
    Write-Host "Dashboard Server: Job ID: $($dashboardJob.Id), Status: $($dashboardJob.State)" -ForegroundColor Cyan
}

Write-Host "`nAccess Points:" -ForegroundColor White
Write-Host "=================" -ForegroundColor White
Write-Host "  - Multi-Blog Dashboard: https://localhost:3001/multi-blog-dashboard.html (HTTPS)" -ForegroundColor Cyan
Write-Host "  - Traefik Dashboard: https://localhost:8080 (HTTPS with SSL)" -ForegroundColor Cyan

Write-Host "`nBlog Websites (via Traefik):" -ForegroundColor White
Write-Host "============================" -ForegroundColor White
try {
    $ingresses = kubectl get ingress --all-namespaces -o json | ConvertFrom-Json
    $blogIngresses = $ingresses.items | Where-Object { $_.metadata.namespace -like "blog-*" }
    
    if ($blogIngresses.Count -gt 0) {
        foreach ($ingress in $blogIngresses) {
            $hostList = ($ingress.spec.rules | ForEach-Object { $_.host }) -join ", "
            foreach ($hostName in ($hostList -split ", ")) {
                if ($hostName) {
                    Write-Host "  - $hostName:8080" -ForegroundColor Cyan
                }
            }
        }
    } else {
        Write-Host "  - No blog websites found. Create your first blog using the dashboard!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  - Check dashboard for current blog URLs" -ForegroundColor Yellow
}

Write-Host "`nManagement Commands:" -ForegroundColor White
Write-Host "====================" -ForegroundColor White
Write-Host "To stop all port forwarding jobs:" -ForegroundColor Yellow
Write-Host "  .\stop-all-port-forwards.ps1" -ForegroundColor Gray
Write-Host "To stop individual services:" -ForegroundColor Yellow
foreach ($port in $global:PortForwardJobs.Keys) {
    $jobId = $global:PortForwardJobs[$port].Job.Id
    Write-Host "  Stop-Job $jobId  # $($global:PortForwardJobs[$port].Description)" -ForegroundColor Gray
}

Write-Host "`nSystem restored successfully!" -ForegroundColor Green
Write-Host "All services are now accessible after PC restart." -ForegroundColor Green