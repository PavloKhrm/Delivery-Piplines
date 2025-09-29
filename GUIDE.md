# Multi-Tenant Kubernetes Blog Template System - Complete Guide

## Overview

This is a comprehensive multi-tenant Kubernetes deployment system designed for isolated blog applications. Each client deployment gets its own complete infrastructure stack including backend, frontend, database, cache, search, and mail services with automated configuration and port management.

## Architecture

### Core Components

1. **NestJS Backend** - Node.js API server with TypeORM, authentication, and caching
2. **Vue.js Frontend** - Modern SPA with PrimeVue UI components  
3. **MySQL 8.0** - Primary database with optimized configuration
4. **Redis 7.4** - Session storage and caching layer
5. **Elasticsearch 8.15** - Full-text search and analytics
6. **MailCrab** - SMTP testing and email capture
7. **Traefik** - Load balancer and ingress controller

### Infrastructure Features

- **Isolated Namespaces** - Each client gets their own Kubernetes namespace
- **Dynamic Port Allocation** - Automatic port assignment prevents conflicts  
- **Auto-Generated Secrets** - Secure password and API key generation
- **Helm-Based Templating** - Production-ready Kubernetes manifests
- **Traefik Load Balancing** - Advanced routing and middleware support
- **Health Checks & Monitoring** - Built-in liveness and readiness probes
- **Resource Management** - CPU/memory limits and requests
- **Persistent Storage** - StatefulSets with PVCs for databases
- **Security Hardening** - Pod security contexts and network policies

## Prerequisites

### Required Tools
```powershell
# Install via Chocolatey
choco install docker-desktop kubernetes-cli kind kubernetes-helm -y

# Start Docker Desktop and create Kind cluster
kind create cluster --name k8s-blog-template
```

### System Requirements
- Windows 10/11 with PowerShell 5.1+
- Docker Desktop running
- 8GB+ RAM available
- 50GB+ disk space

## Quick Start

### 1. Install Traefik (Load Balancer)
```powershell
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --namespace traefik-system --create-namespace --wait
kubectl apply -f traefik-config/middlewares.yaml
```

### 2. Generate Client Deployment
```powershell
# Create a new client deployment
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "acme-corp" -Environment "production"

# List all clients
.\template-generator\Show-Clients.ps1

# Deploy the client
cd deployments\acme-corp
.\deploy.ps1
```

## Project Structure

```
├── basic-blog/                    # Source applications
│   ├── basic-backend/            # NestJS API server
│   └── basic-frontend/           # Vue.js SPA
├── helm-blog-template/           # Helm chart templates
│   ├── Chart.yaml               # Chart metadata
│   ├── values.yaml              # Default configuration
│   └── templates/               # Kubernetes manifests
├── template-generator/           # Client management tools
│   ├── Generate-ClientDeployment.ps1  # Create new client
│   ├── Show-Clients.ps1              # View all clients  
│   └── Remove-Client.ps1             # Clean removal
├── traefik-config/              # Load balancer setup
└── deployments/                # Generated client configs
    └── [client-name]/          # Per-client directory
```

## Template Generator System

### Generate New Client
```powershell
.\template-generator\Generate-ClientDeployment.ps1 `
  -ClientName "client-name" `
  -Environment "production" `
  -Domain "client.example.com" `
  -CloudApiEndpoint "https://api.example.com" `
  -BitbucketRepo "org/client-repo"
```

**Features:**
- Validates client name format
- Allocates unique ports (30000-32767 range)
- Generates secure passwords (32+ characters)
- Creates environment-specific configurations
- Supports dev/staging/production environments

### Port Management

The system automatically manages port allocation:

- **Backend API**: Auto-assigned external port
- **Frontend Web**: Auto-assigned external port  
- **MySQL**: Auto-assigned external port
- **Redis**: Auto-assigned external port
- **Elasticsearch**: Auto-assigned external port
- **MailCrab**: Auto-assigned external port

Ports are tracked in `used-ports.json` to prevent conflicts.

### Environment-Specific Scaling

**Development:**
- 1 replica per service
- 10GB MySQL, 2GB Redis, 10GB Elasticsearch
- Basic resource limits

**Staging:**  
- 2 backend replicas
- 20GB MySQL, 5GB Redis, 30GB Elasticsearch
- Moderate resource allocation

**Production:**
- 3 backend replicas, 2 frontend replicas
- 50GB MySQL, 10GB Redis, 100GB Elasticsearch  
- Auto-scaling enabled
- TLS certificates
- Enhanced monitoring

## Multi-Client Deployment

### Deploy Multiple Clients
```powershell
# Production clients
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "acme-corp" -Environment "production"
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "tech-startup" -Environment "production"
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "enterprise-co" -Environment "production"

# Deploy each client
cd deployments\acme-corp
.\deploy.ps1
cd ..\..

cd deployments\tech-startup
.\deploy.ps1
cd ..\..
```

### Access Multiple Applications

#### Option A: Port Forwarding (Recommended)
```powershell
# Client 1: acme-corp (localhost:8080)
kubectl port-forward -n blog-acme-corp-production svc/acme-corp-frontend 8080:80

# Client 2: tech-startup (localhost:8081) - NEW TERMINAL
kubectl port-forward -n blog-tech-startup-production svc/tech-startup-frontend 8081:80
```

#### Option B: NodePort Access
```powershell
# Get Kind cluster IP
docker inspect k8s-blog-template-control-plane | Select-String "IPAddress"

# Access each client directly by their allocated ports
# Example: http://172.18.0.2:30007
```

#### Option C: Host File Setup
Add to `C:\Windows\System32\drivers\etc\hosts`:
```
127.0.0.1 acme-corp.production.local
127.0.0.1 tech-startup.production.local
```

## Security Features

### Generated Secrets
- Database passwords (32 chars)
- Redis passwords (32 chars)  
- Elasticsearch passwords (32 chars)
- JWT secrets (64 chars)
- Session secrets (64 chars)
- Client API keys (64 chars)
- Webhook secrets (32 chars)

### Traefik Middlewares
- Rate limiting (100 req/min burst, 50 avg)
- Security headers (HSTS, XSS protection)
- CORS configuration
- Circuit breakers
- Request/response size limits
- IP whitelisting for admin access

### Pod Security
- Non-root containers
- Read-only root filesystems  
- Dropped capabilities
- Security contexts
- Network policies (optional)

## Management Commands

### List All Clients
```powershell
.\template-generator\Show-Clients.ps1
```

### Remove Client
```powershell
.\template-generator\Remove-Client.ps1 -ClientName "old-client"
```

### Check All Deployments Status
```powershell
# Check all blog namespaces
kubectl get namespaces | Select-String "blog"

# Check all client pods
kubectl get pods --all-namespaces | Select-String "blog"

# Check specific clients
kubectl get all -n blog-acme-corp-production
```

### Monitor Multiple Clients
```powershell
# Check logs across all clients
kubectl logs -n blog-acme-corp-production deployment/acme-corp-backend --tail=10

# Monitor resource usage
kubectl top pods --all-namespaces | Select-String "blog"
kubectl top nodes
```

### Scaling Multiple Clients
```powershell
# Scale individual client
kubectl scale deployment acme-corp-backend --replicas=5 -n blog-acme-corp-production

# Scale multiple clients
kubectl scale deployment tech-startup-backend --replicas=3 -n blog-tech-startup-production
```

## Troubleshooting

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker Images Not Building
```powershell
# Build manually
docker build -t blog-backend:acme-corp basic-blog/basic-backend/
docker build -t blog-frontend:acme-corp basic-blog/basic-frontend/

# Load into Kind
kind load docker-image blog-backend:acme-corp --name k8s-blog-template
kind load docker-image blog-frontend:acme-corp --name k8s-blog-template
```

### Pods Not Starting
```powershell
# Check pod status
kubectl describe pod -n blog-acme-corp-production [POD-NAME]

# Check events
kubectl get events -n blog-acme-corp-production --sort-by='.lastTimestamp'
```

### Port Conflicts
```powershell
# Delete port registry and regenerate
Remove-Item used-ports.json -ErrorAction SilentlyContinue
.\template-generator\Generate-ClientDeployment.ps1 -ClientName "acme-corp" -Environment "production"
```

## CI/CD Integration

### Bitbucket Pipelines

The system supports integration with Bitbucket for automated deployments:

1. **Webhook Integration** - Auto-generated webhook secrets
2. **Environment Variables** - Pre-configured for CI/CD
3. **Cloud API Connection** - Sync with external APIs
4. **Multi-Environment** - Dev/staging/production workflows

### Cloudflare Integration (Planned)

- DNS management
- SSL certificate automation
- CDN configuration  
- Security policies

## Production Deployment

### Cloud Provider Setup
1. **Hetzner Cloud** - Recommended for cost-effective Kubernetes
2. **kubectl Configuration** - Point to production cluster
3. **Persistent Storage** - Configure storage classes
4. **Load Balancer** - External IP for Traefik

### Security Hardening  
1. **TLS Certificates** - Let's Encrypt integration
2. **Network Policies** - Restrict pod-to-pod communication
3. **RBAC** - Role-based access control
4. **Secrets Management** - External secret providers

### Monitoring Stack
1. **Prometheus** - Metrics collection
2. **Grafana** - Visualization dashboards
3. **Loki** - Log aggregation  
4. **AlertManager** - Incident notifications

## Use Cases

### SaaS Platform
- Each customer gets isolated infrastructure
- Automated onboarding with template generator
- Scalable from dev to enterprise

### Agency/Consulting
- Multiple client projects in one cluster  
- Isolated environments prevent cross-contamination
- Easy client handoff with generated configs

### Multi-Environment Development
- Consistent dev/staging/production setup
- Feature branch deployments
- Integration testing isolation

## Success Verification

After deployment, verify:
- Client appears in `.\template-generator\Show-Clients.ps1`
- All pods running: `kubectl get pods -n blog-[CLIENT]-[ENV]`
- Services accessible: `kubectl get services -n blog-[CLIENT]-[ENV]`
- Frontend loads: Port forward and visit localhost
- Backend API responds: Check health endpoint

## System Benefits

### Complete Isolation
- **Data Security**: Each client has separate databases, no data mixing
- **Resource Isolation**: CPU, memory, and storage limits per client
- **Network Segmentation**: Separate namespaces prevent cross-talk
- **Secret Management**: Individual passwords and API keys

### Operational Excellence
- **Independent Scaling**: Scale each client based on their needs
- **Rolling Updates**: Update one client without affecting others
- **Fault Tolerance**: One client failure doesn't impact others
- **Monitoring**: Individual metrics and logs per client

### Cost Efficiency
- **Resource Sharing**: Shared Kubernetes cluster infrastructure
- **Automated Management**: Scripts handle all deployment complexity
- **Port Management**: Automatic allocation prevents conflicts
- **Easy Cleanup**: Remove clients completely with one command

## Next Steps

1. **Deploy Multiple Clients**: Start with 2-3 clients to test isolation
2. **Set up Monitoring**: Monitor each client independently
3. **Configure CI/CD**: Automate deployments per client
4. **Enable TLS**: Set up certificates for production domains
5. **Scale Infrastructure**: Add more nodes as you add clients

This multi-tenant blog platform provides complete isolation between clients with automatic port allocation, secret generation, and scalable architecture for unlimited client deployments.
