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

### 1. SSL Certificate Setup (Recommended)
```powershell
# Set up SSL certificates for local development
.\setup-ssl-complete.ps1
```

This will:
- Install `mkcert` for local certificate generation
- Create trusted SSL certificates for all blog domains
- Configure Traefik for HTTPS with automatic HTTP→HTTPS redirect
- Set up port forwarding for secure access

### 2. Install Traefik (Load Balancer)
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

## Database Management

### Database Setup and Seeding

After deploying your blog applications, you need to set up the database tables and seed them with sample data.

#### 1. Database Table Creation and Seeding

The system includes a comprehensive database seeding script that:
- Creates the `blog_posts` table in each MySQL database
- Seeds 100 sample blog posts with random content using Faker.js
- Works across all deployed blog namespaces

**Run Database Setup:**
```powershell
# Set up all databases (creates tables + seeds data)
.\setup-databases-working.ps1
```

This script will:
- Create `blog_posts` table in each MySQL database
- Seed 100 random blog posts per database
- Use correct MySQL credentials from Kubernetes secrets
- Handle all three blog namespaces (demo, my-company, tech-blog)

#### 2. Manual Database Operations

**Check Database Status:**
```powershell
# Check if tables exist
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "
const { DataSource } = require('typeorm');
const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js');

async function checkTables() {
    const dataSource = new DataSource(mySqlDataSourceOptions);
    await dataSource.initialize();
    const result = await dataSource.query('SHOW TABLES');
    console.log('Tables:', result);
    await dataSource.destroy();
}
checkTables().catch(console.error);
"
```

**Check Blog Post Count:**
```powershell
# Count blog posts in each database
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "
const { DataSource } = require('typeorm');
const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js');

async function countPosts() {
    const dataSource = new DataSource(mySqlDataSourceOptions);
    await dataSource.initialize();
    const result = await dataSource.query('SELECT COUNT(*) as count FROM blog_posts');
    console.log('Blog posts:', result[0].count);
    await dataSource.destroy();
}
countPosts().catch(console.error);
"
```

#### 3. Custom Seeding

**Run Individual Seeders:**
```powershell
# Seed only the demo blog
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- npm run seed

# Seed only my-company blog
kubectl exec -n blog-my-company-dev $(kubectl get pods -n blog-my-company-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- npm run seed

# Seed only tech-blog
kubectl exec -n blog-tech-blog-dev $(kubectl get pods -n blog-tech-blog-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- npm run seed
```

**Custom Seeder Development:**
```typescript
// Create custom seeder: src/database/seeders/custom-seeder.ts
import { Seeder } from '@concepta/typeorm-seeding';
import { faker } from '@faker-js/faker';
import mySqlDataSource from '@/providers/database/datasource';
import { BlogPost } from '../../models/blog-post/entities/blog-post.entity';

export class CustomSeeder extends Seeder {
  async run() {
    const datasource = await mySqlDataSource.initialize();
    const blogPostRepository = datasource.getRepository(BlogPost);

    // Create custom blog posts
    for (let i = 0; i < 50; i++) {
      const post = new BlogPost();
      post.title = `Custom Post ${i + 1}: ${faker.lorem.sentence()}`;
      post.content = faker.lorem.paragraphs(3, '\n\n');
      await blogPostRepository.save(post);
    }
  }
}
```

#### 4. Database Migration (Advanced)

**Manual Table Creation:**
```powershell
# Create tables manually via MySQL pod
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}") -- mysql -u root -p"eABUkpfk6XoEmOiR*tsXaVZG6QzUGsln" blog_db -e "
CREATE TABLE IF NOT EXISTS blog_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);"
```

**Reset Database:**
```powershell
# Drop and recreate tables
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}") -- mysql -u root -p"eABUkpfk6XoEmOiR*tsXaVZG6QzUGsln" blog_db -e "
DROP TABLE IF EXISTS blog_posts;
CREATE TABLE blog_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);"
```

#### 5. Seeding Verification

**Verify Seeding Success:**
```powershell
# Check all blogs have data
Write-Host "Checking Demo Blog..." -ForegroundColor Yellow
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "
const { DataSource } = require('typeorm');
const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js');

async function verify() {
    const dataSource = new DataSource(mySqlDataSourceOptions);
    await dataSource.initialize();
    const result = await dataSource.query('SELECT COUNT(*) as count FROM blog_posts');
    console.log('Demo Blog Posts:', result[0].count);
    await dataSource.destroy();
}
verify().catch(console.error);
"
```

**Access Seeded Data:**
- **Demo Blog**: http://demo.dev.local:8080/
- **My Company Blog**: http://mycomponay.local:8080/
- **Tech Blog**: http://tech.local:8080/

Each blog will display 100 sample blog posts with random hacker-themed content generated by Faker.js.

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

## SSL/TLS Configuration

### Local Development with HTTPS

The system supports SSL/TLS certificates for secure local development using `mkcert`:

#### Automatic Setup
```powershell
# Run the complete SSL setup
.\setup-ssl-complete.ps1
```

#### Manual Setup
```powershell
# Install mkcert
choco install mkcert -y

# Install local CA
mkcert -install

# Generate certificates
mkcert -cert-file ssl-certificates/blog-cert.pem -key-file ssl-certificates/blog-key.pem demo.dev.local tech.local meow.dev.local localhost

# Create Kubernetes secret
kubectl create secret tls blog-ssl-cert --cert=ssl-certificates/blog-cert.pem --key=ssl-certificates/blog-key.pem -n traefik-system
```

#### Accessing Blogs with HTTPS
- **Demo Blog**: `https://demo.dev.local:8080/`
- **Tech Blog**: `https://tech.local:8080/`
- **Meow Blog**: `https://meow.dev.local:8080/`

#### SSL Features
- ✅ **Automatic HTTP→HTTPS redirect**
- ✅ **Trusted certificates** (no browser warnings)
- ✅ **Wildcard support** for subdomains
- ✅ **Auto-renewal** via mkcert
- ✅ **Production-ready** configuration

### Production SSL Setup

For production deployments, use cert-manager with Let's Encrypt:

```yaml
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure Let's Encrypt issuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
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

### Database Issues

**Table Not Found Error:**
```powershell
# If you get "Table 'blog_db.blog_posts' doesn't exist"
# Run the database setup script
.\setup-databases-working.ps1
```

**Seeding Fails:**
```powershell
# Check if backend pods are running
kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend"

# Check backend logs for errors
kubectl logs -n blog-demo-dev deployment/demo-backend --tail=20

# Verify database connection
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "
const { DataSource } = require('typeorm');
const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js');

async function testConnection() {
    try {
        const dataSource = new DataSource(mySqlDataSourceOptions);
        await dataSource.initialize();
        console.log('Database connection successful');
        await dataSource.destroy();
    } catch (error) {
        console.error('Database connection failed:', error.message);
    }
}
testConnection();
"
```

**Empty Blog Lists:**
```powershell
# Check if data exists in database
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "
const { DataSource } = require('typeorm');
const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js');

async function checkData() {
    const dataSource = new DataSource(mySqlDataSourceOptions);
    await dataSource.initialize();
    const result = await dataSource.query('SELECT COUNT(*) as count FROM blog_posts');
    console.log('Blog posts count:', result[0].count);
    
    if (result[0].count === 0) {
        console.log('No data found. Run: .\\setup-databases-working.ps1');
    }
    await dataSource.destroy();
}
checkData().catch(console.error);
"
```

**MySQL Connection Refused:**
```powershell
# Check MySQL pod status
kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=mysql"

# Check MySQL logs
kubectl logs -n blog-demo-dev deployment/demo-mysql --tail=20

# Restart MySQL if needed
kubectl rollout restart deployment/demo-mysql -n blog-demo-dev
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

## Quick Reference

### Essential Commands

**System Setup:**
```powershell
# Complete system setup
.\setup-fresh-machine.ps1

# Database setup and seeding
.\setup-databases-working.ps1

# Update hosts file (run as Administrator)
.\update-hosts.ps1

# Start dashboard server
node command-runner.js
```

**Access Points:**
- **Dashboard**: http://localhost:3001/
- **Demo Blog**: http://demo.dev.local:8080/
- **My Company Blog**: http://mycomponay.local:8080/
- **Tech Blog**: http://tech.local:8080/

**Port Forwarding (Alternative Access):**
```powershell
# Demo blog
kubectl port-forward -n blog-demo-dev service/demo-frontend 8081:80

# My Company blog  
kubectl port-forward -n blog-my-company-dev service/my-company-frontend 8083:80

# Tech blog
kubectl port-forward -n blog-tech-blog-dev service/tech-blog-frontend 8084:80
```

**Database Operations:**
```powershell
# Check blog post count
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- node -e "const { DataSource } = require('typeorm'); const { mySqlDataSourceOptions } = require('./dist/providers/database/datasource.js'); async function count() { const ds = new DataSource(mySqlDataSourceOptions); await ds.initialize(); const result = await ds.query('SELECT COUNT(*) as count FROM blog_posts'); console.log('Posts:', result[0].count); await ds.destroy(); } count().catch(console.error);"

# Re-seed specific blog
kubectl exec -n blog-demo-dev $(kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}") -- npm run seed
```

**Troubleshooting:**
```powershell
# Check all pods
kubectl get pods --all-namespaces | Select-String "blog"

# Check specific blog status
kubectl get all -n blog-demo-dev

# View logs
kubectl logs -n blog-demo-dev deployment/demo-backend --tail=20

# Restart services
kubectl rollout restart deployment/demo-backend -n blog-demo-dev
```
