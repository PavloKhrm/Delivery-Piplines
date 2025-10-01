# Multi-Tenant Kubernetes Blog Template System - Backup Script
# Creates a complete backup of the system including images, manifests, and data

param(
    [Parameter(Mandatory = $true)]
    [string]$BackupName,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath = ".\backups"
)

$ErrorActionPreference = "Stop"

Write-Host "Multi-Tenant Kubernetes Blog Template System - Backup" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# Create backup directory
$backupDir = Join-Path $BackupPath $BackupName
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fullBackupDir = "$backupDir-$timestamp"

Write-Host "Creating backup directory: $fullBackupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $fullBackupDir -Force | Out-Null

# Function to export Docker images
function Export-DockerImages {
    Write-Host "🐳 Exporting Docker images..." -ForegroundColor Yellow
    
    $imagesDir = Join-Path $fullBackupDir "docker-images"
    New-Item -ItemType Directory -Path $imagesDir -Force | Out-Null
    
    # Export backend image
    Write-Host "  Exporting blog-backend:latest..." -ForegroundColor Yellow
    docker save blog-backend:latest -o "$imagesDir\blog-backend.tar"
    
    # Export frontend image
    Write-Host "  Exporting blog-frontend:latest..." -ForegroundColor Yellow
    docker save blog-frontend:latest -o "$imagesDir\blog-frontend.tar"
    
    Write-Host "✅ Docker images exported" -ForegroundColor Green
}

# Function to export Kubernetes manifests
function Export-KubernetesManifests {
    Write-Host "☸️ Exporting Kubernetes manifests..." -ForegroundColor Yellow
    
    $manifestsDir = Join-Path $fullBackupDir "kubernetes-manifests"
    New-Item -ItemType Directory -Path $manifestsDir -Force | Out-Null
    
    # Export all namespaces
    Write-Host "  Exporting namespaces..." -ForegroundColor Yellow
    kubectl get namespaces -o yaml > "$manifestsDir\namespaces.yaml"
    
    # Export all blog namespaces
    $blogNamespaces = kubectl get namespaces -o json | ConvertFrom-Json | Where-Object { $_.metadata.name -like "blog-*" }
    
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        Write-Host "  Exporting namespace: $nsName" -ForegroundColor Yellow
        
        $nsDir = Join-Path $manifestsDir $nsName
        New-Item -ItemType Directory -Path $nsDir -Force | Out-Null
        
        # Export all resources in the namespace
        kubectl get all -n $nsName -o yaml > "$nsDir\all-resources.yaml"
        kubectl get configmaps -n $nsName -o yaml > "$nsDir\configmaps.yaml"
        kubectl get secrets -n $nsName -o yaml > "$nsDir\secrets.yaml"
        kubectl get ingress -n $nsName -o yaml > "$nsDir\ingress.yaml"
        kubectl get pvc -n $nsName -o yaml > "$nsDir\persistentvolumeclaims.yaml"
    }
    
    Write-Host "✅ Kubernetes manifests exported" -ForegroundColor Green
}

# Function to export database dumps
function Export-DatabaseDumps {
    Write-Host "🗄️ Exporting database dumps..." -ForegroundColor Yellow
    
    $dbDir = Join-Path $fullBackupDir "database-dumps"
    New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
    
    $blogNamespaces = kubectl get namespaces -o json | ConvertFrom-Json | Where-Object { $_.metadata.name -like "blog-*" }
    
    foreach ($namespace in $blogNamespaces) {
        $nsName = $namespace.metadata.name
        Write-Host "  Exporting database for: $nsName" -ForegroundColor Yellow
        
        try {
            # Get MySQL pod name
            $mysqlPod = kubectl get pods -n $nsName -l app=mysql -o jsonpath='{.items[0].metadata.name}'
            
            if ($mysqlPod) {
                # Create database dump
                kubectl exec -n $nsName $mysqlPod -- mysqldump --all-databases --single-transaction --routines --triggers > "$dbDir\$nsName-database.sql"
                Write-Host "    ✅ Database dump created for $nsName" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ No MySQL pod found for $nsName" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    ❌ Failed to export database for $nsName" -ForegroundColor Red
        }
    }
    
    Write-Host "✅ Database dumps exported" -ForegroundColor Green
}

# Function to export configuration files
function Export-ConfigurationFiles {
    Write-Host "⚙️ Exporting configuration files..." -ForegroundColor Yellow
    
    $configDir = Join-Path $fullBackupDir "configuration"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    
    # Copy important configuration files
    $configFiles = @(
        "helm-blog-template\values.yaml",
        "helm-blog-template\templates\*.yaml",
        "template-generator\*.ps1",
        "multi-blog-dashboard.html",
        "command-runner.js",
        "package.json",
        "package-lock.json"
    )
    
    foreach ($pattern in $configFiles) {
        if (Test-Path $pattern) {
            Copy-Item $pattern $configDir -Recurse -Force
            Write-Host "  Copied: $pattern" -ForegroundColor Yellow
        }
    }
    
    # Export deployment configurations
    if (Test-Path "deployments") {
        Copy-Item "deployments" $configDir -Recurse -Force
        Write-Host "  Copied: deployments directory" -ForegroundColor Yellow
    }
    
    Write-Host "✅ Configuration files exported" -ForegroundColor Green
}

# Function to create backup manifest
function Create-BackupManifest {
    Write-Host "📋 Creating backup manifest..." -ForegroundColor Yellow
    
    $manifest = @{
        backupName = $BackupName
        timestamp = $timestamp
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        system = @{
            os = (Get-WmiObject -Class Win32_OperatingSystem).Caption
            powershell = $PSVersionTable.PSVersion.ToString()
            docker = (docker --version).Trim()
            kubectl = (kubectl version --client --short).Trim()
            helm = (helm version --short).Trim()
        }
        namespaces = @()
        images = @("blog-backend:latest", "blog-frontend:latest")
    }
    
    # Get blog namespaces
    $blogNamespaces = kubectl get namespaces -o json | ConvertFrom-Json | Where-Object { $_.metadata.name -like "blog-*" }
    foreach ($namespace in $blogNamespaces) {
        $manifest.namespaces += $namespace.metadata.name
    }
    
    $manifestPath = Join-Path $fullBackupDir "backup-manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
    
    Write-Host "✅ Backup manifest created" -ForegroundColor Green
}

# Main backup process
try {
    Write-Host "`n🚀 Starting backup process..." -ForegroundColor Cyan
    
    Export-DockerImages
    Export-KubernetesManifests
    Export-DatabaseDumps
    Export-ConfigurationFiles
    Create-BackupManifest
    
    Write-Host "`n🎉 Backup completed successfully!" -ForegroundColor Green
    Write-Host "📁 Backup location: $fullBackupDir" -ForegroundColor Cyan
    Write-Host "📊 Backup size: $((Get-ChildItem $fullBackupDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) MB" -ForegroundColor Cyan
    
    Write-Host "`nBackup contents:" -ForegroundColor Yellow
    Write-Host "  - Docker images (blog-backend.tar, blog-frontend.tar)" -ForegroundColor White
    Write-Host "  - Kubernetes manifests (all namespaces and resources)" -ForegroundColor White
    Write-Host "  - Database dumps (SQL files for each blog)" -ForegroundColor White
    Write-Host "  - Configuration files (templates, scripts, dashboard)" -ForegroundColor White
    Write-Host "  - Backup manifest (metadata and system info)" -ForegroundColor White
    
    Write-Host "`n🔄 To restore this backup, run:" -ForegroundColor Cyan
    Write-Host ".\restore-system.ps1 -BackupName `"$BackupName`"" -ForegroundColor White
    
} catch {
    Write-Host "`n❌ Backup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
