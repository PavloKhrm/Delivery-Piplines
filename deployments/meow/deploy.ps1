# PowerShell deployment script for meow

$ErrorActionPreference = "Stop"

Write-Host "Deploying meow to dev..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:latest $PSScriptRoot/../../basic-blog/basic-backend/
docker build -t blog-frontend:latest $PSScriptRoot/../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install meow $PSScriptRoot/../../helm-blog-template `
  --namespace blog-meow-dev `
  --create-namespace `
  --values $PSScriptRoot/values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://meow.dev.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30079" -ForegroundColor White
Write-Host "  Backend: 30078" -ForegroundColor White
Write-Host "  MySQL: 30080" -ForegroundColor White
Write-Host "  Redis: 30081" -ForegroundColor White
Write-Host "  Elasticsearch: 30082" -ForegroundColor White
Write-Host "  MailCrab: 30083" -ForegroundColor White
