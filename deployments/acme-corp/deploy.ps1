# PowerShell deployment script for acme-corp

$ErrorActionPreference = "Stop"

Write-Host "Deploying acme-corp to production..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:acme-corp ../../basic-blog/basic-backend/
docker build -t blog-frontend:acme-corp ../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:acme-corp --name k8s-blog-template
kind load docker-image blog-frontend:acme-corp --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install acme-corp ../../helm-blog-template `
  --namespace blog-acme-corp-production `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://acme-corp.production.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30007" -ForegroundColor White
Write-Host "  Backend: 30006" -ForegroundColor White
Write-Host "  MySQL: 30008" -ForegroundColor White
Write-Host "  Redis: 30009" -ForegroundColor White
Write-Host "  Elasticsearch: 30010" -ForegroundColor White
Write-Host "  MailCrab: 30011" -ForegroundColor White
