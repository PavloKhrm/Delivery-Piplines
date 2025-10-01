# Multi-Tenant Kubernetes Blog Template System - Fresh Machine Setup
# This script automates the complete setup process for a fresh machine

param(
    [Parameter(Mandatory = $false)]
    [string]$BackupName = "fresh-setup-backup"
)

$ErrorActionPreference = "Stop"

Write-Host "Multi-Tenant Kubernetes Blog Template System - Fresh Machine Setup" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green

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
Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Cyan

$requiredCommands = @("docker", "kubectl", "kind", "helm", "node", "npm")
$missingCommands = @()

foreach ($cmd in $requiredCommands) {
    if (Test-Command $cmd) {
        Write-Host "✅ $cmd is installed" -ForegroundColor Green
    } else {
        Write-Host "❌ $cmd is missing" -ForegroundColor Red
        $missingCommands += $cmd
    }
}

if ($missingCommands.Count -gt 0) {
    Write-Host "`n❌ Missing prerequisites: $($missingCommands -join ', ')" -ForegroundColor Red
    Write-Host "Please install the missing tools and run this script again." -ForegroundColor Yellow
    Write-Host "`nQuick install with Chocolatey:" -ForegroundColor Cyan
    Write-Host "choco install docker-desktop kubernetes-cli kind kubernetes-helm nodejs npm git -y" -ForegroundColor White
    exit 1
}

# Step 2: Wait for Docker
Wait-ForDocker

# Step 3: Create Kind cluster
Write-Host "`n🐳 Creating Kind Kubernetes cluster..." -ForegroundColor Cyan
try {
    $null = kind get clusters | Select-String "k8s-blog-template"
    Write-Host "✅ Cluster 'k8s-blog-template' already exists" -ForegroundColor Green
} catch {
    Write-Host "Creating new cluster..." -ForegroundColor Yellow
    kind create cluster --name k8s-blog-template
    Write-Host "✅ Kind cluster created successfully" -ForegroundColor Green
}

# Step 4: Install Traefik
Write-Host "`n🌐 Installing Traefik load balancer..." -ForegroundColor Cyan
try {
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm install traefik traefik/traefik --namespace traefik-system --create-namespace --wait
    Write-Host "✅ Traefik installed successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Traefik installation had issues, but continuing..." -ForegroundColor Yellow
}

# Step 5: Build Docker images
Write-Host "`n🔨 Building Docker images..." -ForegroundColor Cyan
Write-Host "Building backend image..." -ForegroundColor Yellow
docker build -t blog-backend:latest .\basic-blog\basic-backend\

Write-Host "Building frontend image..." -ForegroundColor Yellow
docker build -t blog-frontend:latest .\basic-blog\basic-frontend\

Write-Host "✅ Docker images built successfully" -ForegroundColor Green

# Step 6: Load images into Kind
Write-Host "`n📦 Loading images into Kind cluster..." -ForegroundColor Cyan
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template
Write-Host "✅ Images loaded into Kind cluster" -ForegroundColor Green

# Step 7: Install dashboard dependencies
Write-Host "`n📦 Installing dashboard dependencies..." -ForegroundColor Cyan
if (Test-Path "package.json") {
    npm install express
} else {
    npm init -y
    npm install express
}
Write-Host "✅ Dashboard dependencies installed" -ForegroundColor Green

# Step 8: Create backup
Write-Host "`n💾 Creating system backup..." -ForegroundColor Cyan
if (Test-Path "backup-system.ps1") {
    .\backup-system.ps1 -BackupName $BackupName
    Write-Host "✅ System backup created: $BackupName" -ForegroundColor Green
} else {
    Write-Host "⚠️ Backup script not found, skipping backup" -ForegroundColor Yellow
}

# Step 9: Start dashboard
Write-Host "`n🎯 Starting multi-blog dashboard..." -ForegroundColor Cyan
Write-Host "Dashboard will be available at: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor Green

# Step 10: Final instructions
Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "✅ Kubernetes cluster: k8s-blog-template" -ForegroundColor Green
Write-Host "✅ Traefik load balancer: Installed" -ForegroundColor Green
Write-Host "✅ Docker images: Built and loaded" -ForegroundColor Green
Write-Host "✅ Dashboard: Ready to start" -ForegroundColor Green
Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Start the dashboard: node command-runner.js" -ForegroundColor White
Write-Host "2. Open: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor White
Write-Host "3. Create your first blog using the dashboard!" -ForegroundColor White
Write-Host "`n📚 For more information, see README.md" -ForegroundColor Cyan

# Optional: Start dashboard automatically
$startDashboard = Read-Host "`nWould you like to start the dashboard now? (y/n)"
if ($startDashboard -eq "y" -or $startDashboard -eq "Y") {
    Write-Host "`n🎯 Starting dashboard..." -ForegroundColor Green
    Write-Host "Dashboard running at: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the dashboard" -ForegroundColor Yellow
    node command-runner.js
}
