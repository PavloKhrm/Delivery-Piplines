#!/bin/bash
# Deployment script for tech-corp

set -e

echo "Deploying tech-corp to production..."

# Build and load images into Kind
echo "Building Docker images..."
docker build -t blog-backend:tech-corp ../../basic-blog/basic-backend/
docker build -t blog-frontend:tech-corp ../../basic-blog/basic-frontend/

echo "Loading images into Kind cluster..."
kind load docker-image blog-backend:tech-corp --name k8s-blog-template
kind load docker-image blog-frontend:tech-corp --name k8s-blog-template

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install tech-corp ../../helm-blog-template \
  --namespace blog-tech-corp-production \
  --create-namespace \
  --values values.yaml \
  --wait \
  --timeout=10m

echo "Deployment completed successfully!"
echo "Access your application at: http://tech-corp.production.local"
echo "External ports allocated:"
echo "  Frontend: 30025"
echo "  Backend: 30024"
echo "  MySQL: 30026"
echo "  Redis: 30027"
echo "  Elasticsearch: 30028"
echo "  MailCrab: 30029"
