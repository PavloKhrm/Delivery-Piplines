# PowerShell deployment script for tech-corp

$ErrorActionPreference = "Stop"

Write-Host "Deploying tech-corp to production..." -ForegroundColor Green

# Build and load images into Kind
Write-Host "Building Docker images..." -ForegroundColor Yellow
docker build -t blog-backend:tech-corp ../../basic-blog/basic-backend/
docker build -t blog-frontend:tech-corp ../../basic-blog/basic-frontend/

Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
kind load docker-image blog-backend:tech-corp --name k8s-blog-template
kind load docker-image blog-frontend:tech-corp --name k8s-blog-template

# Deploy with Helm
Write-Host "Deploying with Helm..." -ForegroundColor Yellow
helm upgrade --install tech-corp ../../helm-blog-template `
  --namespace blog-tech-corp-production `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout=10m

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Access your application at: http://tech-corp.production.local" -ForegroundColor Cyan
Write-Host "External ports allocated:" -ForegroundColor Cyan
Write-Host "  Frontend: 30025" -ForegroundColor White
Write-Host "  Backend: 30024" -ForegroundColor White
Write-Host "  MySQL: 30026" -ForegroundColor White
Write-Host "  Redis: 30027" -ForegroundColor White
Write-Host "  Elasticsearch: 30028" -ForegroundColor White
Write-Host "  MailCrab: 30029" -ForegroundColor White
