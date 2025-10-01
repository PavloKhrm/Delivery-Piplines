Write-Host "Setting up databases with correct MySQL credentials" -ForegroundColor Cyan

Write-Host "`nSetting up Demo Blog..." -ForegroundColor Yellow
$demoMysqlPod = kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}"
if ($demoMysqlPod) {
    Write-Host "Creating blog_posts table via MySQL pod..." -ForegroundColor Yellow
    kubectl exec $demoMysqlPod -n blog-demo-dev -- mysql -u root -p"eABUkpfk6XoEmOiR*tsXaVZG6QzUGsln" blog_db -e "CREATE TABLE IF NOT EXISTS blog_posts (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, content TEXT NOT NULL, createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);"
    
    Write-Host "Running seeders..." -ForegroundColor Yellow
    $demoPod = kubectl get pods -n blog-demo-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}"
    kubectl exec $demoPod -n blog-demo-dev -- npm run seed
    
    Write-Host "Demo blog setup complete" -ForegroundColor Green
} else {
    Write-Host "Demo MySQL pod not found" -ForegroundColor Red
}

Write-Host "`nSetting up My Company Blog..." -ForegroundColor Yellow
$myCompanyMysqlPod = kubectl get pods -n blog-my-company-dev -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}"
if ($myCompanyMysqlPod) {
    Write-Host "Creating blog_posts table via MySQL pod..." -ForegroundColor Yellow
    kubectl exec $myCompanyMysqlPod -n blog-my-company-dev -- mysql -u root -p"eABUkpfk6XoEmOiR*tsXaVZG6QzUGsln" blog_db -e "CREATE TABLE IF NOT EXISTS blog_posts (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, content TEXT NOT NULL, createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);"
    
    Write-Host "Running seeders..." -ForegroundColor Yellow
    $myCompanyPod = kubectl get pods -n blog-my-company-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}"
    kubectl exec $myCompanyPod -n blog-my-company-dev -- npm run seed
    
    Write-Host "My Company blog setup complete" -ForegroundColor Green
} else {
    Write-Host "My Company MySQL pod not found" -ForegroundColor Red
}

Write-Host "`nSetting up Tech Blog..." -ForegroundColor Yellow
$techMysqlPod = kubectl get pods -n blog-tech-blog-dev -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}"
if ($techMysqlPod) {
    Write-Host "Creating blog_posts table via MySQL pod..." -ForegroundColor Yellow
    kubectl exec $techMysqlPod -n blog-tech-blog-dev -- mysql -u root -p"eABUkpfk6XoEmOiR*tsXaVZG6QzUGsln" blog_db -e "CREATE TABLE IF NOT EXISTS blog_posts (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, content TEXT NOT NULL, createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);"
    
    Write-Host "Running seeders..." -ForegroundColor Yellow
    $techPod = kubectl get pods -n blog-tech-blog-dev -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}"
    kubectl exec $techPod -n blog-tech-blog-dev -- npm run seed
    
    Write-Host "Tech blog setup complete" -ForegroundColor Green
} else {
    Write-Host "Tech MySQL pod not found" -ForegroundColor Red
}

Write-Host "`nDatabase setup complete!" -ForegroundColor Green
Write-Host "`nAccess your blogs:" -ForegroundColor Cyan
Write-Host "  Demo: http://demo.dev.local:8080/" -ForegroundColor White
Write-Host "  My Company: http://mycomponay.local:8080/" -ForegroundColor White
Write-Host "  Tech: http://tech.local:8080/" -ForegroundColor White


