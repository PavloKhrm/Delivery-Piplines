#!/bin/bash
# Deployment script for meow

set -e

echo "Deploying meow to dev..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:latest $PSScriptRoot/../../basic-blog/basic-backend/
docker build -t blog-frontend:latest $PSScriptRoot/../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
Push-Location $PSScriptRoot
try {
    helm upgrade --install meow ../../helm-blog-template \
      --namespace blog-meow-dev \
      --create-namespace \
      --values values.yaml \
      --wait \
      --timeout=10m
} finally {
    Pop-Location
}

echo "Deployment completed successfully!"
echo "Access your application at: http://meow.dev.local"
echo "External ports allocated:"
echo "  Frontend: 30079"
echo "  Backend: 30078"
echo "  MySQL: 30080"
echo "  Redis: 30081"
echo "  Elasticsearch: 30082"
echo "  MailCrab: 30083"
