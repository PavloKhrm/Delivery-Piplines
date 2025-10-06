# Complete SSL Setup for Blog System
# This script sets up SSL certificates and configures Traefik for HTTPS

Write-Host "🔐 Setting up SSL certificates for local development..." -ForegroundColor Green

# Step 1: Install mkcert if not present
Write-Host "`n📦 Checking mkcert installation..." -ForegroundColor Yellow
$mkcertInstalled = Get-Command mkcert -ErrorAction SilentlyContinue

if (-not $mkcertInstalled) {
    Write-Host "Installing mkcert..." -ForegroundColor Yellow
    
    # Download mkcert for Windows
    $mkcertUrl = "https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-windows-amd64.exe"
    $mkcertPath = "$env:TEMP\mkcert.exe"
    
    try {
        Invoke-WebRequest -Uri $mkcertUrl -OutFile $mkcertPath
        Move-Item $mkcertPath "$env:USERPROFILE\mkcert.exe"
        $env:PATH += ";$env:USERPROFILE"
        Write-Host "mkcert installed successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install mkcert: $($_.Exception.Message)"
        Write-Host "Please install mkcert manually from: https://github.com/FiloSottile/mkcert" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "mkcert is already installed" -ForegroundColor Green
}

# Step 2: Install local CA
Write-Host "`n🔑 Installing local CA..." -ForegroundColor Yellow
& mkcert -install

# Step 3: Create certificates directory
$certsDir = "ssl-certificates"
if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Path $certsDir
    Write-Host "Created certificates directory: $certsDir" -ForegroundColor Green
}

# Step 4: Generate certificates for all blog domains
$domains = @(
    "demo.dev.local",
    "mycomponay.local", 
    "tech.local",
    "meow.dev.local",
    "localhost",
    "127.0.0.1"
)

Write-Host "`n Generating SSL certificates for domains: $($domains -join ', ')" -ForegroundColor Yellow

# Generate certificate for all domains
$domainList = $domains -join " "
& mkcert -cert-file "$certsDir\blog-cert.pem" -key-file "$certsDir\blog-key.pem" $domainList

if ($LASTEXITCODE -eq 0) {
    Write-Host " SSL certificates generated successfully!" -ForegroundColor Green
    Write-Host " Certificate files:" -ForegroundColor Cyan
    Write-Host "   - $certsDir\blog-cert.pem" -ForegroundColor White
    Write-Host "   - $certsDir\blog-key.pem" -ForegroundColor White
    
    # Step 5: Create Kubernetes secret for the certificates
    Write-Host "`n🔧 Creating Kubernetes secret for SSL certificates..." -ForegroundColor Yellow
    
    # Create secret in traefik-system namespace
    kubectl create secret tls blog-ssl-cert --cert="$certsDir\blog-cert.pem" --key="$certsDir\blog-key.pem" -n traefik-system --dry-run=client -o yaml | kubectl apply -f -
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Kubernetes secret created successfully!" -ForegroundColor Green
    } else {
        Write-Warning " Failed to create Kubernetes secret"
    }
    
    # Step 6: Update Traefik configuration for SSL
    Write-Host "`n Updating Traefik configuration for SSL..." -ForegroundColor Yellow
    
    # Apply the SSL-enabled Traefik configuration
    kubectl apply -f "C:\Users\axayt\Desktop\FuckAroundAndFindOut\Prototype_K8s_SecondAttempt Yarno approach\Prototype_K8s_SecondAttempt\traefik-ssl-config.yaml"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Traefik SSL configuration applied!" -ForegroundColor Green
    } else {
        Write-Warning " Failed to apply Traefik SSL configuration"
    }
    
    # Step 7: Wait for Traefik to be ready
    Write-Host "`n Waiting for Traefik to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=available --timeout=300s deployment/traefik -n traefik-system
    
    # Step 8: Set up port forwarding
    Write-Host "`n Setting up port forwarding..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-Command", "kubectl port-forward -n traefik-system svc/traefik 8080:8080" -WindowStyle Minimized
    
    Write-Host "`n SSL setup complete!" -ForegroundColor Green
    Write-Host "`n Next steps:" -ForegroundColor Cyan
    Write-Host "1.  SSL certificates are installed and trusted" -ForegroundColor White
    Write-Host "2.  Traefik is configured for HTTPS" -ForegroundColor White
    Write-Host "3.  Port forwarding is active on localhost:8080" -ForegroundColor White
    Write-Host "`n Access your blogs via HTTPS:" -ForegroundColor Cyan
    Write-Host "   - https://demo.dev.local:8080/" -ForegroundColor White
    Write-Host "   - https://tech.local:8080/" -ForegroundColor White
    Write-Host "   - https://meow.dev.local:8080/" -ForegroundColor White
    Write-Host "`n Note: All HTTP traffic will be automatically redirected to HTTPS" -ForegroundColor Yellow
    
} else {
    Write-Error " Failed to generate SSL certificates"
    exit 1
}


