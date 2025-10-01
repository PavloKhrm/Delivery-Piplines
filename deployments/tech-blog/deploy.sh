#!/bin/bash
# Deployment script for tech-blog

set -e

echo "Deploying tech-blog to dev..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:latest ../../basic-blog/basic-backend/
docker build -t blog-frontend:latest ../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install tech-blog ../../helm-blog-template \
  --namespace blog-tech-blog-dev \
  --create-namespace \
  --values values.yaml \
  --wait \
  --timeout=10m

echo "Deployment completed successfully!"
echo "Access your application at: http://tech.local"
echo "External ports allocated:"
echo "  Frontend: 30019"
echo "  Backend: 30018"
echo "  MySQL: 30020"
echo "  Redis: 30021"
echo "  Elasticsearch: 30022"
echo "  MailCrab: 30023"
