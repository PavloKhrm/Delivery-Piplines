Write-Host "Interactive database seeding for selected blogs" -ForegroundColor Cyan

function Get-PlainTextFromSecureString($secureString) {
    if (-not $secureString) { return $null }
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-NamespaceList {
    $allNamespaces = kubectl get ns -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" 2>$null
    if (-not $allNamespaces) { return @() }
    # Only namespaces that look like blog namespaces
    return $allNamespaces | Where-Object { $_ -like 'blog-*' }
}

function Get-MysqlPod([string]$Namespace) {
    # Match the label scheme used by the Helm chart (component=mysql)
    return kubectl get pods -n $Namespace -l "app.kubernetes.io/name=blog-template,component=mysql" -o jsonpath="{.items[0].metadata.name}" 2>$null
}

function Get-BackendPod([string]$Namespace) {
    return kubectl get pods -n $Namespace -l "app.kubernetes.io/name=blog-template,component=backend" -o jsonpath="{.items[0].metadata.name}" 2>$null
}

function Try-GetRootPasswordFromSecret([string]$Namespace) {
    try {
        # Heuristic: secret name follows "<client>-blog-template-secrets"
        $client = $Namespace
        $client = $client -replace '^blog-',''
        $client = $client -replace '-dev$',''
        $secretName = "$client-blog-template-secrets"
        $b64 = kubectl get secret $secretName -n $Namespace -o jsonpath="{.data.MYSQL_ROOT_PASSWORD}" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($b64)) {
            # fallback: try to discover any secret containing MYSQL_ROOT_PASSWORD
            $secretNames = kubectl get secret -n $Namespace -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" 2>$null
            foreach ($s in $secretNames) {
                $b64 = kubectl get secret $s -n $Namespace -o jsonpath="{.data.MYSQL_ROOT_PASSWORD}" 2>$null
                if ($b64) { break }
            }
        }
        if ($b64) {
            return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
        }
    } catch { }
    return $null
}

function Ensure-Table-And-Seed([string]$Namespace, [string]$RootPassword) {
    $mysqlPod = Get-MysqlPod -Namespace $Namespace
    if (-not $mysqlPod) {
        Write-Host "MySQL pod not found in namespace $Namespace" -ForegroundColor Red
        return
    }

    Write-Host "Creating blog_posts table in $Namespace..." -ForegroundColor Yellow
    $sql = "CREATE TABLE IF NOT EXISTS blog_posts (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, content TEXT NOT NULL, createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);"
    kubectl exec $mysqlPod -n $Namespace -- mysql -u root -p"$RootPassword" -D blog_db -e "$sql"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create table in $Namespace (wrong password or MySQL not ready)." -ForegroundColor Red
        return
    }

    $backendPod = Get-BackendPod -Namespace $Namespace
    if (-not $backendPod) {
        Write-Host "Backend pod not found in $Namespace" -ForegroundColor Red
        return
    }
    Write-Host "Running seeders in $Namespace..." -ForegroundColor Yellow
    kubectl exec $backendPod -n $Namespace -- npm run seed
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Seeding completed for $Namespace" -ForegroundColor Green
    } else {
        Write-Host "Seeding failed for $Namespace" -ForegroundColor Red
    }
}

Write-Host "\nDetected blog namespaces:" -ForegroundColor Cyan
$namespaces = Get-NamespaceList
if ($namespaces.Count -eq 0) {
    Write-Host "No blog-* namespaces found. Exiting." -ForegroundColor Red
    return
}
$namespaces | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }

while ($true) {
    $ns = Read-Host "\nEnter target namespace (or 'all' to seed every listed namespace, or blank to finish)"
    if ([string]::IsNullOrWhiteSpace($ns)) { break }

    $targetNamespaces = @()
    if ($ns -eq 'all') { $targetNamespaces = $namespaces }
    elseif ($namespaces -contains $ns) { $targetNamespaces = @($ns) }
    else {
        Write-Host "Namespace '$ns' not recognized. Try again." -ForegroundColor Yellow
        continue
    }

    $pwMode = Read-Host "Password mode: (A)uto from secret / (M)anual prompt [A/M]"
    $auto = $true
    if ($pwMode -and $pwMode.ToUpper() -eq 'M') { $auto = $false }

    foreach ($n in $targetNamespaces) {
        $rootPassword = $null
        if ($auto) {
            $rootPassword = Try-GetRootPasswordFromSecret -Namespace $n
            if (-not $rootPassword) {
                Write-Host "Could not auto-detect MySQL root password in $n. Switching to manual prompt." -ForegroundColor Yellow
            }
        }
        if (-not $rootPassword) {
            $secure = Read-Host "Enter MySQL root password for $n" -AsSecureString
            $rootPassword = Get-PlainTextFromSecureString $secure
        }

        Ensure-Table-And-Seed -Namespace $n -RootPassword $rootPassword
    }
}

Write-Host "\nDone." -ForegroundColor Cyan


