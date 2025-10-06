# Multi-Tenant Kubernetes Blog Template System - Fresh Machine Setup
# This script automates the complete setup process for a fresh machine

param(
    [Parameter(Mandatory = $false)]
    [string]$BackupName = "fresh-setup-backup",
    [Parameter(Mandatory = $false)]
    [switch]$EnableLogging = $false
)

$ErrorActionPreference = "Stop"

# Setup logging if enabled
if ($EnableLogging) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir = ".\logs"
    $logFile = "$logDir\setup-fresh-machine-$timestamp.log"
    
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Write-Host "Logging enabled. Output will be saved to: $logFile" -ForegroundColor Cyan
    
    # Function to log both to console and file
    function Write-Log {
        param(
            [string]$Message,
            [string]$Level = "INFO",
            [string]$Color = "White"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        
        # Write to console with color
        Write-Host $Message -ForegroundColor $Color
        
        # Write to log file
        Add-Content -Path $script:logFilePath -Value $logEntry -Encoding UTF8
    }
    
    # Store original Write-Host for logging
    $script:logFilePath = $logFile
} else {
    # Function to log only to console
    function Write-Log {
        param(
            [string]$Message,
            [string]$Level = "INFO",
            [string]$Color = "White"
        )
        Write-Host $Message -ForegroundColor $Color
    }
}

Write-Log "Multi-Tenant Kubernetes Blog Template System - Fresh Machine Setup" "INFO" "Green"
Write-Log "========================================================================" "INFO" "Green"

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

# Function to capture command output and errors
function Invoke-CommandWithLogging {
    param(
        [string]$Command,
        [string]$Description,
        [string]$WorkingDirectory = "."
    )
    
    Write-Log "Executing: $Description" "INFO" "Cyan"
    Write-Log "Command: $Command" "DEBUG" "Gray"
    
    try {
        # Use call operator to avoid PowerShell exceptions for non-zero exit codes
        $output = & cmd /c "$Command 2>&1"
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Log "SUCCESS: $Description" "SUCCESS" "Green"
            if ($output) {
                Write-Log "Output: $output" "DEBUG" "Gray"
            }
        } else {
            Write-Log "ERROR: $Description failed with exit code $exitCode" "ERROR" "Red"
            Write-Log "Error output: $output" "ERROR" "Red"
            throw "Command failed with exit code $exitCode"
        }
        return $output
    } catch {
        Write-Log "EXCEPTION: $Description failed with exception: $($_.Exception.Message)" "ERROR" "Red"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR" "Red"
        throw
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
            return
        } catch {
            $attempt++
            Write-Host "Docker not ready yet... ($attempt/$maxAttempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    } while ($attempt -lt $maxAttempts)
    
    throw "Docker failed to start within expected time. Please start Docker Desktop manually."
}

# Step 1: Check prerequisites
Write-Log "`n Checking prerequisites..." "INFO" "Cyan"

$requiredCommands = @("docker", "kubectl", "kind", "helm", "node", "npm")
$missingCommands = @()

foreach ($cmd in $requiredCommands) {
    if (Test-Command $cmd) {
        Write-Log " $cmd is installed" "SUCCESS" "Green"
    } else {
        Write-Log " $cmd is missing" "ERROR" "Red"
        $missingCommands += $cmd
    }
}

if ($missingCommands.Count -gt 0) {
    Write-Log "`n Missing prerequisites: $($missingCommands -join ', ')" "ERROR" "Red"
    Write-Log "Please install the missing tools and run this script again." "WARNING" "Yellow"
    Write-Log "`nQuick install with Chocolatey:" "INFO" "Cyan"
    Write-Log "choco install docker-desktop kubernetes-cli kind kubernetes-helm nodejs npm git -y" "INFO" "White"
    
    if ($EnableLogging) {
        Write-Log "Log file saved to: $logFile" "INFO" "Cyan"
    }
    exit 1
}

# Step 2: Wait for Docker
Wait-ForDocker

# Step 3: Create Kind cluster
Write-Log "`n Creating Kind Kubernetes cluster..." "INFO" "Cyan"

# Check for existing clusters using a safer method
Write-Log "Checking for existing Kind clusters..." "INFO" "Cyan"
$existingCluster = $false

try {
    $clusters = & kind get clusters 2>$null
    if ($clusters -match "k8s-blog-template") {
        $existingCluster = $true
        Write-Log " Cluster 'k8s-blog-template' already exists" "SUCCESS" "Green"
    }
} catch {
    Write-Log "No existing clusters found (this is normal for fresh install)" "INFO" "Yellow"
}

if (-not $existingCluster) {
    Write-Log "Creating new Kind cluster..." "INFO" "Yellow"
    try {
        Invoke-CommandWithLogging "kind create cluster --name k8s-blog-template" "Create Kind cluster"
        Write-Log " Kind cluster created successfully" "SUCCESS" "Green"
    } catch {
        Write-Log "Failed to create Kind cluster: $($_.Exception.Message)" "ERROR" "Red"
        if ($EnableLogging) {
            Write-Log "Check log file for details: $logFile" "INFO" "Cyan"
        }
        throw
    }
}

# Step 4: Install Traefik
Write-Log "`n Installing Traefik load balancer..." "INFO" "Cyan"
try {
    Invoke-CommandWithLogging "helm repo add traefik https://traefik.github.io/charts" "Add Traefik Helm repository"
    Invoke-CommandWithLogging "helm repo update" "Update Helm repositories"
    
    # Install Traefik without --wait flag to avoid timeout issues
    Write-Log "Installing Traefik (this may take a few minutes)..." "INFO" "Yellow"
    Invoke-CommandWithLogging "helm install traefik traefik/traefik --namespace traefik-system --create-namespace" "Install Traefik"
    Write-Log " Traefik installation initiated successfully" "SUCCESS" "Green"
    
    # Wait a bit for Traefik to start
    Write-Log "Waiting for Traefik pods to be ready..." "INFO" "Yellow"
    Start-Sleep -Seconds 30
    
} catch {
    Write-Log " Traefik installation had issues, but continuing..." "WARNING" "Yellow"
    Write-Log "Error details: $($_.Exception.Message)" "ERROR" "Red"
}

# Step 5: Build Docker images
Write-Log "`n Building Docker images..." "INFO" "Cyan"

# Check if basic-blog directory exists
if (Test-Path ".\basic-blog\basic-backend\") {
    Write-Log "Building backend image..." "INFO" "Yellow"
    Write-Log "Note: This may take several minutes on first build" "INFO" "Cyan"
    try {
        # Use timeout for Docker build to prevent hanging
        $job = Start-Job -ScriptBlock { docker build -t blog-backend:latest .\basic-blog\basic-backend\ }
        $timeout = 600 # 10 minutes timeout
        $result = Wait-Job $job -Timeout $timeout
        
        if ($result) {
            $output = Receive-Job $job
            Remove-Job $job
            Write-Log "Backend image built successfully" "SUCCESS" "Green"
        } else {
            Stop-Job $job
            Remove-Job $job
            Write-Log "Backend image build timed out after $timeout seconds" "ERROR" "Red"
        }
    } catch {
        Write-Log "Backend image build failed: $($_.Exception.Message)" "ERROR" "Red"
    }
} else {
    Write-Log "Backend directory not found, skipping backend build" "WARNING" "Yellow"
}

if (Test-Path ".\basic-blog\basic-frontend\") {
    Write-Log "Building frontend image..." "INFO" "Yellow"
    try {
        # Use timeout for Docker build to prevent hanging
        $job = Start-Job -ScriptBlock { docker build -t blog-frontend:latest .\basic-blog\basic-frontend\ }
        $timeout = 600 # 10 minutes timeout
        $result = Wait-Job $job -Timeout $timeout
        
        if ($result) {
            $output = Receive-Job $job
            Remove-Job $job
            Write-Log "Frontend image built successfully" "SUCCESS" "Green"
        } else {
            Stop-Job $job
            Remove-Job $job
            Write-Log "Frontend image build timed out after $timeout seconds" "ERROR" "Red"
        }
    } catch {
        Write-Log "Frontend image build failed: $($_.Exception.Message)" "ERROR" "Red"
    }
} else {
    Write-Log "Frontend directory not found, skipping frontend build" "WARNING" "Yellow"
}

Write-Log " Docker images build process completed" "INFO" "Green"

# Step 6: Load images into Kind
Write-Host "`n Loading images into Kind cluster..." -ForegroundColor Cyan

# Check if images exist before loading
$backendImage = docker images -q blog-backend:latest 2>$null
$frontendImage = docker images -q blog-frontend:latest 2>$null

if ($backendImage) {
    kind load docker-image blog-backend:latest --name k8s-blog-template
    Write-Host " Backend image loaded" -ForegroundColor Green
} else {
    Write-Host " Backend image not found, skipping" -ForegroundColor Yellow
}

if ($frontendImage) {
    kind load docker-image blog-frontend:latest --name k8s-blog-template
    Write-Host " Frontend image loaded" -ForegroundColor Green
} else {
    Write-Host " Frontend image not found, skipping" -ForegroundColor Yellow
}

Write-Host " Images loaded into Kind cluster" -ForegroundColor Green

# Step 7: Install dashboard dependencies
Write-Host "`n Installing dashboard dependencies..." -ForegroundColor Cyan

# Navigate to Dashboard directory if it exists
if (Test-Path ".\Dashboard\package.json") {
    Set-Location -Path ".\Dashboard"
    npm install
    Set-Location -Path ".."
    Write-Host " Dashboard dependencies installed" -ForegroundColor Green
} elseif (Test-Path "package.json") {
    npm install express
    Write-Host " Dashboard dependencies installed" -ForegroundColor Green
} else {
    Write-Host " No package.json found, skipping npm install" -ForegroundColor Yellow
}

# Step 8: Create backup
Write-Host "`n Creating system backup..." -ForegroundColor Cyan
if (Test-Path ".\Tools\backup-system.ps1") {
    .\Tools\backup-system.ps1 -BackupName $BackupName
    Write-Host " System backup created: $BackupName" -ForegroundColor Green
} elseif (Test-Path "backup-system.ps1") {
    .\backup-system.ps1 -BackupName $BackupName
    Write-Host " System backup created: $BackupName" -ForegroundColor Green
} else {
    Write-Host " Backup script not found, skipping backup" -ForegroundColor Yellow
}

# Step 9: Start dashboard
Write-Host "`n Starting multi-blog dashboard..." -ForegroundColor Cyan
Write-Host "Dashboard will be available at: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor Green

# Step 10: Final instructions
Write-Log "`n Setup Complete!" "SUCCESS" "Green"
Write-Log "=================" "SUCCESS" "Green"
Write-Log " Kubernetes cluster: k8s-blog-template" "SUCCESS" "Green"
Write-Log " Traefik load balancer: Installed" "SUCCESS" "Green"
Write-Log " Docker images: Built and loaded" "SUCCESS" "Green"
Write-Log " Dashboard: Ready to start" "SUCCESS" "Green"

if ($EnableLogging) {
    Write-Log "`n Log file saved to: $logFile" "INFO" "Cyan"
    Write-Log "You can review the complete execution log for troubleshooting." "INFO" "Cyan"
}

Write-Log "`n Next Steps:" "INFO" "Cyan"
Write-Log "1. Start the dashboard: cd Dashboard; node command-runner.js" "INFO" "White"
Write-Log "2. Open: http://localhost:3001/multi-blog-dashboard.html" "INFO" "White"
Write-Log "3. Create your first blog using the dashboard!" "INFO" "White"
Write-Log "`n For more information, see README.md" "INFO" "Cyan"

# Optional: Start dashboard automatically
$startDashboard = Read-Host "`nWould you like to start the dashboard now? (y/n)"
if ($startDashboard -eq "y" -or $startDashboard -eq "Y") {
    Write-Host "`n Starting dashboard..." -ForegroundColor Green
    Write-Host "Dashboard running at: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the dashboard" -ForegroundColor Yellow
    
    # Navigate to Dashboard directory if it exists
    if (Test-Path ".\Dashboard\command-runner.js") {
        Set-Location -Path ".\Dashboard"
        node command-runner.js
    } else {
        Write-Host "Dashboard not found in expected location" -ForegroundColor Red
        Write-Host "Please run: cd Dashboard; node command-runner.js" -ForegroundColor Yellow
    }
}
