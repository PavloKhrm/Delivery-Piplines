# Update Windows Hosts File for Local Domains
# This script automatically adds all blog domains to the Windows hosts file

param(
    [switch]$EnableLogging = $false
)

Write-Host "Updating Windows Hosts File for Local Domains" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Log "ERROR: This script must be run as Administrator to modify the hosts file" "ERROR" "Red"
    Write-Log "Right-click PowerShell and select 'Run as Administrator'" "WARNING" "Yellow"
    exit 1
}

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

Write-Log "`nGetting blog domains from Kubernetes..." "INFO" "Cyan"

# Get all blog namespaces and their domains
$namespaces = kubectl get namespaces -o json | ConvertFrom-Json
$blogNamespaces = $namespaces.items | Where-Object { $_.metadata.name -like "blog-*" }

$newEntries = @()
foreach ($namespace in $blogNamespaces) {
    $nsName = $namespace.metadata.name
    try {
        $ingresses = kubectl get ingress -n $nsName -o json | ConvertFrom-Json
        if ($ingresses.items -and $ingresses.items.Count -gt 0) {
            $host = $ingresses.items[0].spec.rules[0].host
            $newEntries += "127.0.0.1 $host"
            Write-Log "Found domain: $host for namespace $nsName" "INFO" "Yellow"
        }
    } catch {
        Write-Log "Failed to get ingress for namespace $nsName" "WARNING" "Yellow"
    }
}

if ($newEntries.Count -eq 0) {
    Write-Log "No blog domains found to add to hosts file" "WARNING" "Yellow"
    exit 0
}

Write-Log "`nUpdating hosts file..." "INFO" "Cyan"

try {
    # Read current hosts file
    $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
    
    # Remove existing blog entries (lines starting with 127.0.0.1 and containing .local)
    $filteredHosts = $currentHosts | Where-Object { 
        $_ -notmatch "^127\.0\.0\.1.*\.local.*$" -and 
        $_ -notmatch "^#.*blog.*domain.*$" 
    }
    
    # Add new entries
    $updatedHosts = $filteredHosts + "" + "# Blog domains (auto-generated)" + $newEntries
    
    # Write updated hosts file
    $updatedHosts | Out-File -FilePath $hostsFile -Encoding ASCII
    
    Write-Log "Hosts file updated successfully!" "SUCCESS" "Green"
    Write-Log "Added $($newEntries.Count) domain entries:" "INFO" "Cyan"
    foreach ($entry in $newEntries) {
        Write-Log "  $entry" "INFO" "White"
    }
    
} catch {
    Write-Log "Failed to update hosts file: $($_.Exception.Message)" "ERROR" "Red"
    Write-Log "You may need to manually add these entries to $hostsFile:" "WARNING" "Yellow"
    foreach ($entry in $newEntries) {
        Write-Log "  $entry" "INFO" "White"
    }
}

Write-Log "`nHosts file update complete!" "SUCCESS" "Green"
Write-Log "You can now access your blogs using their domain names" "INFO" "Cyan"
