# Multi-Tenant Kubernetes Blog Template System - Migration Helper
# This script helps you migrate your blog system to a new machine

param(
    [Parameter(Mandatory = $false)]
    [string]$BackupName = "migration-backup"
)

$ErrorActionPreference = "Stop"

Write-Host "Multi-Tenant Kubernetes Blog Template System - Migration Helper" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green

Write-Host "`nThis script will help you migrate your blog system to a new machine." -ForegroundColor Cyan
Write-Host "`nStep 1: Create backup on current machine" -ForegroundColor Yellow
Write-Host "Step 2: Transfer backup to new machine" -ForegroundColor Yellow
Write-Host "Step 3: Restore on new machine" -ForegroundColor Yellow

$continue = Read-Host "`nDo you want to create a backup now? (y/n)"
if ($continue -eq "y" -or $continue -eq "Y") {
    Write-Host "`nCreating backup..." -ForegroundColor Cyan
    .\backup-system-simple.ps1 -BackupName $BackupName
    
    Write-Host "`nBackup created successfully!" -ForegroundColor Green
    Write-Host "`nNext steps for migration:" -ForegroundColor Cyan
    Write-Host "1. Copy the backup folder to your new machine" -ForegroundColor White
    Write-Host "2. Install prerequisites on new machine:" -ForegroundColor White
    Write-Host "   choco install docker-desktop kubernetes-cli kind kubernetes-helm nodejs npm git -y" -ForegroundColor Gray
    Write-Host "3. Clone the repository on new machine" -ForegroundColor White
    Write-Host "4. Copy backup folder to .\backups\ directory" -ForegroundColor White
    Write-Host "5. Run: .\restore-system.ps1 -BackupName `"$BackupName`" -FreshMachine" -ForegroundColor White
    
    Write-Host "`nBackup location: .\backups\$BackupName-[timestamp]" -ForegroundColor Yellow
} else {
    Write-Host "`nMigration cancelled." -ForegroundColor Yellow
    Write-Host "`nTo create backup manually, run:" -ForegroundColor Cyan
    Write-Host ".\backup-system-simple.ps1 -BackupName `"your-backup-name`"" -ForegroundColor White
}
