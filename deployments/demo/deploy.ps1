# PowerShell deployment script for demo

$ErrorActionPreference = "Stop"

Write-Host "Deploying demo to dev..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:latest ../../basic-blog/basic-backend/
docker build -t blog-frontend:latest ../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install demo ../../helm-blog-template `
  --namespace blog-demo-dev `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://demo.dev.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30013" -ForegroundColor White
Write-Host "  Backend: 30012" -ForegroundColor White
Write-Host "  MySQL: 30014" -ForegroundColor White
Write-Host "  Redis: 30015" -ForegroundColor White
Write-Host "  Elasticsearch: 30016" -ForegroundColor White
Write-Host "  MailCrab: 30017" -ForegroundColor White
