# Setup SSL Certificates for Local Development
# This script installs mkcert and generates SSL certificates for all blog domains

Write-Host "Setting up SSL certificates for local development..." -ForegroundColor Green

# Check if mkcert is installed
$mkcertInstalled = Get-Command mkcert -ErrorAction SilentlyContinue

if (-not $mkcertInstalled) {
    Write-Host "Installing mkcert..." -ForegroundColor Yellow
    
    # Download mkcert for Windows
    $mkcertUrl = "https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-windows-amd64.exe"
    $mkcertPath = "$env:TEMP\mkcert.exe"
    
    try {
        Invoke-WebRequest -Uri $mkcertUrl -OutFile $mkcertPath
        Move-Item $mkcertPath "$env:USERPROFILE\mkcert.exe"
        Write-Host "mkcert installed successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install mkcert: $($_.Exception.Message)"
        Write-Host "Please install mkcert manually from: https://github.com/FiloSottile/mkcert" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "mkcert is already installed" -ForegroundColor Green
}

# Install the local CA
Write-Host "Installing local CA..." -ForegroundColor Yellow
& mkcert -install

# Create certificates directory
$certsDir = "ssl-certificates"
if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Path $certsDir
}

# Generate certificates for all blog domains
$domains = @(
    "demo.dev.local",
    "mycomponay.local", 
    "tech.local",
    "meow.dev.local",
    "localhost"
)

Write-Host "Generating SSL certificates for domains: $($domains -join ', ')" -ForegroundColor Yellow

# Generate certificate for all domains
$domainList = $domains -join " "
& mkcert -cert-file "$certsDir\blog-cert.pem" -key-file "$certsDir\blog-key.pem" $domainList

if ($LASTEXITCODE -eq 0) {
    Write-Host "SSL certificates generated successfully!" -ForegroundColor Green
    Write-Host "Certificate files:" -ForegroundColor Cyan
    Write-Host "  - $certsDir\blog-cert.pem" -ForegroundColor White
    Write-Host "  - $certsDir\blog-key.pem" -ForegroundColor White
    
    # Create Kubernetes secret for the certificates
    Write-Host "Creating Kubernetes secret for SSL certificates..." -ForegroundColor Yellow
    
    $certContent = Get-Content "$certsDir\blog-cert.pem" -Raw
    $keyContent = Get-Content "$certsDir\blog-key.pem" -Raw
    
    # Create secret in traefik-system namespace
    kubectl create secret tls blog-ssl-cert --cert="$certsDir\blog-cert.pem" --key="$certsDir\blog-key.pem" -n traefik-system --dry-run=client -o yaml | kubectl apply -f -
    
    Write-Host "SSL certificates setup complete!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Update your hosts file with the domains" -ForegroundColor White
    Write-Host "2. Access your blogs via HTTPS: https://demo.dev.local:8080/" -ForegroundColor White
    Write-Host "3. The certificates will be automatically used by Traefik" -ForegroundColor White
} else {
    Write-Error "Failed to generate SSL certificates"
    exit 1
}


