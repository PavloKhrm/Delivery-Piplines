#!/bin/bash
# Deployment script for demo

set -e

echo "Deploying demo to dev..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:latest ../../basic-blog/basic-backend/
docker build -t blog-frontend:latest ../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:latest --name k8s-blog-template
kind load docker-image blog-frontend:latest --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install demo ../../helm-blog-template \
  --namespace blog-demo-dev \
  --create-namespace \
  --values values.yaml \
  --wait \
  --timeout=10m

echo "Deployment completed successfully!"
echo "Access your application at: http://demo.dev.local"
echo "External ports allocated:"
echo "  Frontend: 30013"
echo "  Backend: 30012"
echo "  MySQL: 30014"
echo "  Redis: 30015"
echo "  Elasticsearch: 30016"
echo "  MailCrab: 30017"
