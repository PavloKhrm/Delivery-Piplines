# Multi-Tenant Kubernetes Blog Template System - Restore Script
# Restores a complete system from backup including images, manifests, and data

param(
    [Parameter(Mandatory = $true)]
    [string]$BackupName,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath = ".\backups",
    
    [Parameter(Mandatory = $false)]
    [switch]$FreshMachine
)

$ErrorActionPreference = "Stop"

Write-Host "🔄 Multi-Tenant Kubernetes Blog Template System - Restore" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# Find backup directory
$backupDirs = Get-ChildItem -Path $BackupPath -Directory | Where-Object { $_.Name -like "$BackupName-*" } | Sort-Object Name -Descending

if ($backupDirs.Count -eq 0) {
    Write-Host "❌ No backup found with name: $BackupName" -ForegroundColor Red
    Write-Host "Available backups:" -ForegroundColor Yellow
    Get-ChildItem -Path $BackupPath -Directory | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
    exit 1
}

$backupDir = $backupDirs[0].FullName
Write-Host "📁 Using backup: $($backupDirs[0].Name)" -ForegroundColor Cyan

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Cyan
    
    $requiredCommands = @("docker", "kubectl", "kind", "helm")
    $missingCommands = @()
    
    foreach ($cmd in $requiredCommands) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            Write-Host "✅ $cmd is available" -ForegroundColor Green
        } catch {
            Write-Host "❌ $cmd is missing" -ForegroundColor Red
            $missingCommands += $cmd
        }
    }
    
    if ($missingCommands.Count -gt 0) {
        Write-Host "`n❌ Missing prerequisites: $($missingCommands -join ', ')" -ForegroundColor Red
        Write-Host "Please install the missing tools and run this script again." -ForegroundColor Yellow
        exit 1
    }
}

# Function to wait for Docker
function Wait-ForDocker {
    Write-Host "⏳ Waiting for Docker to be ready..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0
    
    do {
        try {
            $null = docker info 2>$null
            Write-Host "✅ Docker is ready!" -ForegroundColor Green
            return
        } catch {
            $attempt++
            Write-Host "⏳ Docker not ready yet... ($attempt/$maxAttempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    } while ($attempt -lt $maxAttempts)
    
    throw "❌ Docker failed to start within expected time. Please start Docker Desktop manually."
}

# Function to import Docker images
function Import-DockerImages {
    Write-Host "`n🐳 Importing Docker images..." -ForegroundColor Cyan
    
    $imagesDir = Join-Path $backupDir "docker-images"
    
    if (Test-Path "$imagesDir\blog-backend.tar") {
        Write-Host "  Importing blog-backend:latest..." -ForegroundColor Yellow
        docker load -i "$imagesDir\blog-backend.tar"
    }
    
    if (Test-Path "$imagesDir\blog-frontend.tar") {
        Write-Host "  Importing blog-frontend:latest..." -ForegroundColor Yellow
        docker load -i "$imagesDir\blog-frontend.tar"
    }
    
    Write-Host "✅ Docker images imported" -ForegroundColor Green
}

# Function to setup Kind cluster
function Setup-KindCluster {
    Write-Host "`n🐳 Setting up Kind cluster..." -ForegroundColor Cyan
    
    if ($FreshMachine) {
        Write-Host "  Creating new Kind cluster..." -ForegroundColor Yellow
        kind create cluster --name k8s-blog-template
    } else {
        Write-Host "  Using existing Kind cluster..." -ForegroundColor Yellow
    }
    
    # Load images into Kind
    Write-Host "  Loading images into Kind cluster..." -ForegroundColor Yellow
    kind load docker-image blog-backend:latest --name k8s-blog-template
    kind load docker-image blog-frontend:latest --name k8s-blog-template
    
    Write-Host "✅ Kind cluster ready" -ForegroundColor Green
}

# Function to install Traefik
function Install-Traefik {
    Write-Host "`n🌐 Installing Traefik..." -ForegroundColor Cyan
    
    try {
        helm repo add traefik https://traefik.github.io/charts
        helm repo update
        helm install traefik traefik/traefik --namespace traefik-system --create-namespace --wait
        Write-Host "✅ Traefik installed" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Traefik installation had issues, but continuing..." -ForegroundColor Yellow
    }
}

# Function to restore Kubernetes manifests
function Restore-KubernetesManifests {
    Write-Host "`n☸️ Restoring Kubernetes manifests..." -ForegroundColor Cyan
    
    $manifestsDir = Join-Path $backupDir "kubernetes-manifests"
    
    if (Test-Path "$manifestsDir\namespaces.yaml") {
        Write-Host "  Restoring namespaces..." -ForegroundColor Yellow
        kubectl apply -f "$manifestsDir\namespaces.yaml"
    }
    
    # Restore each blog namespace
    $blogDirs = Get-ChildItem -Path $manifestsDir -Directory | Where-Object { $_.Name -like "blog-*" }
    
    foreach ($blogDir in $blogDirs) {
        $nsName = $blogDir.Name
        Write-Host "  Restoring namespace: $nsName" -ForegroundColor Yellow
        
        # Apply manifests in order
        $manifestFiles = @(
            "persistentvolumeclaims.yaml",
            "configmaps.yaml",
            "secrets.yaml",
            "all-resources.yaml",
            "ingress.yaml"
        )
        
        foreach ($file in $manifestFiles) {
            $filePath = Join-Path $blogDir.FullName $file
            if (Test-Path $filePath) {
                try {
                    kubectl apply -f $filePath
                } catch {
                    Write-Host "    ⚠️ Warning applying $file" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "✅ Kubernetes manifests restored" -ForegroundColor Green
}

# Function to restore database dumps
function Restore-DatabaseDumps {
    Write-Host "`n🗄️ Restoring database dumps..." -ForegroundColor Cyan
    
    $dbDir = Join-Path $backupDir "database-dumps"
    $dbFiles = Get-ChildItem -Path $dbDir -Filter "*.sql"
    
    foreach ($dbFile in $dbFiles) {
        $nsName = $dbFile.BaseName -replace "-database$", ""
        Write-Host "  Restoring database for: $nsName" -ForegroundColor Yellow
        
        try {
            # Get MySQL pod name
            $mysqlPod = kubectl get pods -n $nsName -l app=mysql -o jsonpath='{.items[0].metadata.name}'
            
            if ($mysqlPod) {
                # Wait for MySQL to be ready
                kubectl wait --for=condition=ready pod/$mysqlPod -n $nsName --timeout=60s
                
                # Restore database
                kubectl exec -i -n $nsName $mysqlPod -- mysql < $dbFile.FullName
                Write-Host "    ✅ Database restored for $nsName" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ No MySQL pod found for $nsName" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    ❌ Failed to restore database for $nsName" -ForegroundColor Red
        }
    }
    
    Write-Host "✅ Database dumps restored" -ForegroundColor Green
}

# Function to restore configuration files
function Restore-ConfigurationFiles {
    Write-Host "`n⚙️ Restoring configuration files..." -ForegroundColor Cyan
    
    $configDir = Join-Path $backupDir "configuration"
    
    if (Test-Path $configDir) {
        Write-Host "  Restoring configuration files..." -ForegroundColor Yellow
        
        # Copy back important files
        $importantFiles = @(
            "helm-blog-template",
            "template-generator",
            "deployments",
            "multi-blog-dashboard.html",
            "command-runner.js",
            "package.json"
        )
        
        foreach ($item in $importantFiles) {
            $sourcePath = Join-Path $configDir $item
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath . -Recurse -Force
                Write-Host "    Restored: $item" -ForegroundColor Yellow
            }
        }
        
        Write-Host "✅ Configuration files restored" -ForegroundColor Green
    }
}

# Function to install dashboard dependencies
function Install-DashboardDependencies {
    Write-Host "`n📦 Installing dashboard dependencies..." -ForegroundColor Cyan
    
    if (Test-Path "package.json") {
        npm install express
        Write-Host "✅ Dashboard dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ No package.json found, skipping dependency installation" -ForegroundColor Yellow
    }
}

# Function to verify restoration
function Verify-Restoration {
    Write-Host "`n🔍 Verifying restoration..." -ForegroundColor Cyan
    
    # Check namespaces
    $blogNamespaces = kubectl get namespaces -o json | ConvertFrom-Json | Where-Object { $_.metadata.name -like "blog-*" }
    Write-Host "📊 Found $($blogNamespaces.Count) blog namespaces:" -ForegroundColor Yellow
    foreach ($ns in $blogNamespaces) {
        Write-Host "  - $($ns.metadata.name)" -ForegroundColor White
    }
    
    # Check pods
    $totalPods = 0
    $runningPods = 0
    
    foreach ($ns in $blogNamespaces) {
        $nsName = $ns.metadata.name
        $pods = kubectl get pods -n $nsName --no-headers
        $totalPods += ($pods | Measure-Object).Count
        $runningPods += ($pods | Where-Object { $_ -like "*Running*" } | Measure-Object).Count
    }
    
    Write-Host "📊 Pod status: $runningPods/$totalPods running" -ForegroundColor Yellow
    
    if ($runningPods -gt 0) {
        Write-Host "✅ Restoration appears successful!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Some pods may still be starting up" -ForegroundColor Yellow
    }
}

# Main restore process
try {
    Test-Prerequisites
    Wait-ForDocker
    
    Write-Host "`n🚀 Starting restore process..." -ForegroundColor Cyan
    
    Import-DockerImages
    Setup-KindCluster
    Install-Traefik
    Restore-KubernetesManifests
    Restore-DatabaseDumps
    Restore-ConfigurationFiles
    Install-DashboardDependencies
    Verify-Restoration
    
    Write-Host "`n🎉 Restore completed successfully!" -ForegroundColor Green
    Write-Host "📁 Restored from: $backupDir" -ForegroundColor Cyan
    
    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Start the dashboard: node command-runner.js" -ForegroundColor White
    Write-Host "2. Open: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor White
    Write-Host "3. Check your restored blogs!" -ForegroundColor White
    
    # Optional: Start dashboard automatically
    $startDashboard = Read-Host "`nWould you like to start the dashboard now? (y/n)"
    if ($startDashboard -eq "y" -or $startDashboard -eq "Y") {
        Write-Host "`n🎯 Starting dashboard..." -ForegroundColor Green
        Write-Host "Dashboard running at: http://localhost:3001/multi-blog-dashboard.html" -ForegroundColor Cyan
        Write-Host "Press Ctrl+C to stop the dashboard" -ForegroundColor Yellow
        node command-runner.js
    }
    
} catch {
    Write-Host "`n❌ Restore failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
