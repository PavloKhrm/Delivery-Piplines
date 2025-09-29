#!/bin/bash
# Deployment script for startup-xyz

set -e

echo "Deploying startup-xyz to dev..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:startup-xyz ../../basic-blog/basic-backend/
docker build -t blog-frontend:startup-xyz ../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:startup-xyz --name k8s-blog-template
kind load docker-image blog-frontend:startup-xyz --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install startup-xyz ../../helm-blog-template \
  --namespace blog-startup-xyz-dev \
  --create-namespace \
  --values values.yaml \
  --wait \
  --timeout=10m

echo "Deployment completed successfully!"
echo "Access your application at: http://startup-xyz.dev.local"
echo "External ports allocated:"
echo "  Frontend: 30031"
echo "  Backend: 30030"
echo "  MySQL: 30032"
echo "  Redis: 30033"
echo "  Elasticsearch: 30034"
echo "  MailCrab: 30035"
