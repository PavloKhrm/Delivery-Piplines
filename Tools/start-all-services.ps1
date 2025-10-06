# Start All Services Script
Write-Host "Starting all blog services..." -ForegroundColor Green

# Stop existing jobs
Get-Job | Stop-Job | Out-Null
Get-Job | Remove-Job | Out-Null

Write-Host "Starting Traefik port forwards..." -ForegroundColor Yellow
Start-Job -ScriptBlock { kubectl port-forward -n traefik-system service/traefik 8080:8080 }
Start-Job -ScriptBlock { kubectl port-forward -n traefik-system service/traefik 8443:443 }

Write-Host "Starting Demo Frontend port forward..." -ForegroundColor Yellow  
Start-Job -ScriptBlock { kubectl port-forward -n blog-demo-dev-dev service/demo-dev-frontend 9001:80 }

Write-Host "Starting Emit-It Frontend port forward..." -ForegroundColor Yellow
Start-Job -ScriptBlock { kubectl port-forward -n blog-emit-it-dev service/emit-it-frontend 9002:80 }

Write-Host "Starting Tech Blog 2 Frontend port forward..." -ForegroundColor Yellow
Start-Job -ScriptBlock { kubectl port-forward -n blog-tech-blog2-dev service/tech-blog2-frontend 9003:80 }

Start-Sleep -Seconds 5

Write-Host "`n✅ All services started!" -ForegroundColor Green
Write-Host "`nAccess URLs:" -ForegroundColor Cyan
Write-Host "• Demo Blog: http://localhost:9001/" -ForegroundColor White
Write-Host "• Emit-It Blog: http://localhost:9002/" -ForegroundColor White  
Write-Host "• Tech Blog 2: http://localhost:9003/" -ForegroundColor White
Write-Host "• HTTPS Domains: https://demo-dev.local:8443/" -ForegroundColor White

Write-Host "`nManagement commands:" -ForegroundColor Cyan
Write-Host "• Check jobs: Get-Job" -ForegroundColor White
Write-Host "• Stop all: Get-Job | Stop-Job" -ForegroundColor White
