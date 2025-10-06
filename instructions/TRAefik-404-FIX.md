# Traefik 404 On New Blog Creation - Root Cause and Fix

## Problem
Newly created blogs returned HTTP 404 via Traefik, even though pods and services were running.

## Root Causes
- Ingress annotations included unsupported or invalid keys:
  - `traefik.ingress.kubernetes.io/router.middlewares` referencing non-existent middlewares
  - `traefik.ingress.kubernetes.io/router.rule` leading to parsing errors
- Traefik logs showed: `Failed to parse annotations error="field not found, node: rule"`

## Permanent Fixes Implemented
1. Helm template cleanup:
   - Removed custom `router.rule` annotation from `helm-blog-template/templates/ingress.yaml`
   - Removed middleware reference by clearing `ingress.annotations` in `helm-blog-template/values.yaml`
2. Dashboard automation:
   - After deploying a new blog, the dashboard automatically removes problematic annotations from the created Ingress:
     - `traefik.ingress.kubernetes.io/router.middlewares-`
     - `traefik.ingress.kubernetes.io/router.rule-`
   - Waits briefly for Traefik to reload before showing the final URL

## Manual Recovery (if needed)
If a new blog still returns 404, run:
```powershell
kubectl annotate ingress <client>-blog-template-ingress -n blog-<client>-dev traefik.ingress.kubernetes.io/router.middlewares- --overwrite
kubectl annotate ingress <client>-blog-template-ingress -n blog-<client>-dev traefik.ingress.kubernetes.io/router.rule- --overwrite
```

## Verification
- Check Traefik logs for absence of `Failed to parse annotations` errors
- Access the blog over HTTPS:
```bash
curl -k https://<domain>.local:8443/
```

## Notes
- TLS is served with self-signed certificates for local domains
- Traefik service is exposed via NodePort and forwarded locally to 8443
