#!/bin/bash
# Deployment script for emit-it

set -e

echo "Deploying emit-it to dev..."

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
    helm upgrade --install emit-it ../../helm-blog-template \
      --namespace blog-emit-it-dev \
      --create-namespace \
      --values values.yaml \
      --wait \
      --timeout=10m
} finally {
    Pop-Location
}

echo "Deployment completed successfully!"
echo "Access your application at: http://emit-it.dev.local"
echo "External ports allocated:"
echo "  Frontend: 30085"
echo "  Backend: 30084"
echo "  MySQL: 30086"
echo "  Redis: 30087"
echo "  Elasticsearch: 30088"
echo "  MailCrab: 30089"
