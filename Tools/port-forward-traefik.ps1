# Port Forwarding Script for Traefik
Write-Host "Starting Traefik port forwarding..." -ForegroundColor Green
Write-Host "HTTP:  http://localhost:8080" -ForegroundColor Cyan
Write-Host "HTTPS: https://localhost:8443" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Yellow

kubectl port-forward -n traefik-system service/traefik 8080:80 8443:443
