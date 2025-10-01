# PowerShell deployment script for tech-blog

$ErrorActionPreference = "Stop"

Write-Host "Deploying tech-blog to dev..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:latest ../../basic-blog/basic-backend/
docker build -t blog-frontend:latest ../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install tech-blog ../../helm-blog-template `
  --namespace blog-tech-blog-dev `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://tech.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30019" -ForegroundColor White
Write-Host "  Backend: 30018" -ForegroundColor White
Write-Host "  MySQL: 30020" -ForegroundColor White
Write-Host "  Redis: 30021" -ForegroundColor White
Write-Host "  Elasticsearch: 30022" -ForegroundColor White
Write-Host "  MailCrab: 30023" -ForegroundColor White
