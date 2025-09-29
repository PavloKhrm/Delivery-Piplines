#!/bin/bash
# Deployment script for acme-corp

set -e

echo "Deploying acme-corp to production..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:acme-corp ../../basic-blog/basic-backend/
docker build -t blog-frontend:acme-corp ../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:acme-corp --name k8s-blog-template
kind load docker-image blog-frontend:acme-corp --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install acme-corp ../../helm-blog-template \
  --namespace blog-acme-corp-production \
  --create-namespace \
  --values values.yaml \
  --wait \
  --timeout=10m

echo "Deployment completed successfully!"
echo "Access your application at: http://acme-corp.production.local"
echo "External ports allocated:"
echo "  Frontend: 30007"
echo "  Backend: 30006"
echo "  MySQL: 30008"
echo "  Redis: 30009"
echo "  Elasticsearch: 30010"
echo "  MailCrab: 30011"
