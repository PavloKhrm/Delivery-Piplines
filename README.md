# Multi-Tenant Kubernetes Blog Template System

## Overview

A comprehensive multi-tenant Kubernetes deployment system for isolated blog applications. Each client deployment gets its own complete infrastructure stack with automated configuration and port management.

## Quick Start

```powershell
# Install prerequisites
choco install docker-desktop kubernetes-cli kind kubernetes-helm -y

# Create cluster
kind create cluster --name k8s-blog-template

# Install Traefik
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik --namespace traefik-system --create-namespace --wait

# Generate and deploy client
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "acme-corp" -Environment "production"
cd deployments\acme-corp
.\deploy.ps1
```

## Architecture

**Core Components:**
- NestJS Backend (API server)
- Vue.js Frontend (SPA)
- MySQL 8.0 (Database)
- Redis 7.4 (Cache)
- Elasticsearch 8.15 (Search)
- MailCrab (Email testing)
- Traefik (Load balancer)

**Features:**
- Isolated namespaces per client
- Dynamic port allocation
- Auto-generated secrets
- Helm-based templating
- Health checks and monitoring
- Resource management
- Security hardening

## Documentation

For complete setup instructions, troubleshooting, and advanced configuration, see **[GUIDE.md](GUIDE.md)**.

## Project Structure

```
├── basic-blog/                  # Source applications
├── helm-blog-template/         # Helm chart templates
├── template-generator/         # Client management tools
├── traefik-config/            # Load balancer setup
└── deployments/               # Generated client configs
```

## Management Commands

```powershell
# Generate new client
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "client-name" -Environment "production"

# List all clients
.\template-generator\Show-Clients.ps1

# Remove client
.\template-generator\Remove-Client.ps1 -ClientName "old-client"
```

## Use Cases

- **SaaS Platform**: Isolated infrastructure per customer
- **Agency/Consulting**: Multiple client projects in one cluster
- **Multi-Environment Development**: Consistent dev/staging/production setup

## License

MIT License - see LICENSE file for details.
