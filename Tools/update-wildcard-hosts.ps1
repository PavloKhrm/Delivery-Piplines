# Update Wildcard Hosts File
# This script ensures that the wildcard domain *.emit-it.local is properly configured

param(
    [string]$BlogName = "",
    [switch]$EnableLogging = $false
)

Write-Host "Updating Wildcard Hosts File" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    
    if ($EnableLogging) {
        $logFile = ".\logs\wildcard-hosts-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Starting wildcard hosts file update..." "INFO" "Cyan"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Log "This script requires Administrator privileges to modify the hosts file" "ERROR" "Red"
    Write-Log "Please run as Administrator or manually add the following entry to your hosts file:" "WARNING" "Yellow"
    Write-Log "127.0.0.1 *.emit-it.local" "INFO" "White"
    exit 1
}

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

try {
    Write-Log "Reading current hosts file..." "INFO" "Yellow"
    $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
    
    # Check if wildcard entry already exists
    $wildcardEntry = "127.0.0.1 *.emit-it.local"
    $wildcardExists = $currentHosts | Where-Object { $_ -like "*\*.emit-it.local*" }
    
    if (-not $wildcardExists) {
        Write-Log "Adding wildcard domain entry to hosts file..." "INFO" "Yellow"
        
        # Remove any old emit-it.local entries (keep them for reference)
        $filteredHosts = $currentHosts | Where-Object { 
            $_ -notmatch "^127\.0\.0\.1.*emit-it\.local.*$" -and 
            $_ -notmatch "^#.*emit-it.*domain.*$" 
        }
        
        # Add wildcard entry and comment
        $newEntries = @(
            "",
            "# Wildcard domain for blog system (*.emit-it.local)",
            $wildcardEntry,
            "# This allows any subdomain like my-blog.emit-it.local to resolve to localhost"
        )
        
        $updatedHosts = $filteredHosts + $newEntries
        $updatedHosts | Out-File -FilePath $hostsFile -Encoding ASCII
        
        Write-Log "Wildcard domain entry added successfully" "SUCCESS" "Green"
        Write-Log "Added: $wildcardEntry" "INFO" "White"
    } else {
        Write-Log "Wildcard domain entry already exists in hosts file" "SUCCESS" "Green"
    }
    
    # If a specific blog name was provided, add that specific domain too
    if ($BlogName) {
        $specificDomain = "$BlogName.emit-it.local"
        $specificEntry = "127.0.0.1 $specificDomain"
        
        $specificExists = $currentHosts | Where-Object { $_ -like "*$specificDomain*" }
        
        if (-not $specificExists) {
            Write-Log "Adding specific domain for blog: $BlogName" "INFO" "Yellow"
            
            $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
            $currentHosts + "" + $specificEntry | Out-File -FilePath $hostsFile -Encoding ASCII
            
            Write-Log "Added: $specificEntry" "INFO" "White"
        } else {
            Write-Log "Specific domain for $BlogName already exists" "INFO" "Yellow"
        }
    }
    
    Write-Log "Wildcard hosts file update completed successfully" "SUCCESS" "Green"
    
} catch {
    Write-Log "Failed to update hosts file: $($_.Exception.Message)" "ERROR" "Red"
    exit 1
}

Write-Log "`nSummary:" "INFO" "Cyan"
Write-Log "- Wildcard domain *.emit-it.local configured in hosts file" "INFO" "White"
Write-Log "- All subdomains like [blog-name].emit-it.local will resolve to localhost" "INFO" "White"
Write-Log "- No need to manually add individual domains for new blogs" "INFO" "White"
Write-Log "- Works with wildcard SSL certificate *.emit-it.local" "INFO" "White"
