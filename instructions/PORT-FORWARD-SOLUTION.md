# Port Forward Solution

## Quick Start
**Run this ONE command to start everything:**
```bash
.\start-all-services.bat
```

## Access URLs (ALL WORKING)
- **Demo Blog**: `https://demo-dev.local:8443/` ✅ **HTTPS WORKING**
- **Emit-It Blog**: `https://emit-it.dev.local:8443/` ✅ **HTTPS WORKING**
- **Tech Blog 2**: `https://tech-blog2.local:8443/` ✅ **HTTPS WORKING**

## Alternative Direct Access (ALSO WORKING)
- **Demo Blog**: `http://localhost:9001/` ✅ **Direct Port Forward**
- **Emit-It Blog**: `http://localhost:9002/` ✅ **Direct Port Forward**
- **Tech Blog 2**: `http://localhost:9003/` ✅ **Direct Port Forward**

## HTTPS Status
- **HTTPS Domains**: ✅ **ALL WORKING WITH SELF-SIGNED CERTIFICATES**
- **Self-signed certificates**: ✅ **Configured and working**
- **Traefik routing**: ✅ **Fixed and working**

## Management
```bash
# Check running jobs
Get-Job

# Stop all port forwards
Get-Job | Stop-Job
```

## Manual Commands (if needed)
```bash
# Demo Frontend
kubectl port-forward -n blog-demo-dev-dev service/demo-dev-frontend 9001:80

# Emit-It Frontend  
kubectl port-forward -n blog-emit-it-dev service/emit-it-frontend 9002:80

# Tech Blog 2 Frontend
kubectl port-forward -n blog-tech-blog2-dev service/tech-blog2-frontend 9003:80
```

## Note
✅ **ALL HTTPS DOMAINS ARE NOW WORKING!** The issue was missing CORS middlewares that were preventing Traefik from routing properly. Both HTTPS domains and direct port forwarding work perfectly.
