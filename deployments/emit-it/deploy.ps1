# PowerShell deployment script for emit-it

$ErrorActionPreference = "Stop"

Write-Host "Deploying emit-it to dev..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:latest $PSScriptRoot/../../basic-blog/basic-backend/
docker build -t blog-frontend:latest $PSScriptRoot/../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install emit-it $PSScriptRoot/../../helm-blog-template `
  --namespace blog-emit-it-dev `
  --create-namespace `
  --values $PSScriptRoot/values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://emit-it.dev.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30085" -ForegroundColor White
Write-Host "  Backend: 30084" -ForegroundColor White
Write-Host "  MySQL: 30086" -ForegroundColor White
Write-Host "  Redis: 30087" -ForegroundColor White
Write-Host "  Elasticsearch: 30088" -ForegroundColor White
Write-Host "  MailCrab: 30089" -ForegroundColor White
