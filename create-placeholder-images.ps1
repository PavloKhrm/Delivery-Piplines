# Create Placeholder Docker Images
# This script creates placeholder Docker images when basic-blog directories don't exist

param(
    [switch]$EnableLogging = $false
)

Write-Host "Creating placeholder Docker images..." -ForegroundColor Cyan

# Create backend placeholder image
Write-Host "Creating backend placeholder image..." -ForegroundColor Yellow
try {
    # Pull nginx:alpine if not exists
    docker pull nginx:alpine
    
    # Create temporary container
    docker run -d --name temp-backend nginx:alpine
    
    # Commit as blog-backend:latest
    docker commit temp-backend blog-backend:latest
    
    # Clean up
    docker rm -f temp-backend
    
    Write-Host "Backend placeholder image created successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to create backend placeholder image: $($_.Exception.Message)" -ForegroundColor Red
}

# Create frontend placeholder image
Write-Host "Creating frontend placeholder image..." -ForegroundColor Yellow
try {
    # Create temporary container
    docker run -d --name temp-frontend nginx:alpine
    
    # Commit as blog-frontend:latest
    docker commit temp-frontend blog-frontend:latest
    
    # Clean up
    docker rm -f temp-frontend
    
    Write-Host "Frontend placeholder image created successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to create frontend placeholder image: $($_.Exception.Message)" -ForegroundColor Red
}

# Load images into Kind cluster
Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow
try {
    kind load docker-image blog-backend:latest --name k8s-blog-template
    kind load docker-image blog-frontend:latest --name k8s-blog-template
    Write-Host "Images loaded into Kind cluster successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to load images into Kind cluster: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Placeholder images creation completed!" -ForegroundColor Green
Write-Host "You can now try deploying your blog again." -ForegroundColor Cyan
