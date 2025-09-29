# PowerShell deployment script for startup-xyz

$ErrorActionPreference = "Stop"

Write-Host "Deploying startup-xyz to dev..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:startup-xyz ../../basic-blog/basic-backend/
docker build -t blog-frontend:startup-xyz ../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:startup-xyz --name k8s-blog-template
kind load docker-image blog-frontend:startup-xyz --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install startup-xyz ../../helm-blog-template `
  --namespace blog-startup-xyz-dev `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://startup-xyz.dev.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30031" -ForegroundColor White
Write-Host "  Backend: 30030" -ForegroundColor White
Write-Host "  MySQL: 30032" -ForegroundColor White
Write-Host "  Redis: 30033" -ForegroundColor White
Write-Host "  Elasticsearch: 30034" -ForegroundColor White
Write-Host "  MailCrab: 30035" -ForegroundColor White
