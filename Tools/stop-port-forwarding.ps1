# Stop Port Forwarding for Local Domain Access
# This script stops all kubectl port forwarding processes

param(
    [switch]$EnableLogging = $false
)

Write-Host "Stopping Port Forwarding for Local Domain Access" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

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
        $logFile = ".\logs\stop-port-forwarding-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        if (!(Test-Path ".\logs")) {
            New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
        }
        Add-Content -Path $logFile -Value $logMessage
    }
}

Write-Log "Searching for kubectl port forwarding processes..." "INFO" "Cyan"

# Find all kubectl processes that are doing port forwarding
try {
    $kubectlProcesses = Get-Process -Name "kubectl" -ErrorAction SilentlyContinue
    $portForwardProcesses = @()
    
    foreach ($process in $kubectlProcesses) {
        try {
            # Get command line arguments for the process
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($commandLine -and $commandLine -like "*port-forward*") {
                $portForwardProcesses += $process
                Write-Log "Found port forwarding process (PID: $($process.Id))" "INFO" "Yellow"
            }
        } catch {
            # Skip processes where we can't get command line
        }
    }
    
    if ($portForwardProcesses.Count -eq 0) {
        Write-Log "No kubectl port forwarding processes found" "INFO" "Yellow"
    } else {
        Write-Log "Stopping $($portForwardProcesses.Count) port forwarding process(es)..." "INFO" "Cyan"
        
        foreach ($process in $portForwardProcesses) {
            try {
                Stop-Process -Id $process.Id -Force
                Write-Log "Stopped process PID: $($process.Id)" "SUCCESS" "Green"
            } catch {
                Write-Log "Failed to stop process PID: $($process.Id) - $($_.Exception.Message)" "ERROR" "Red"
            }
        }
    }
    
} catch {
    Write-Log "Error searching for kubectl processes: $($_.Exception.Message)" "ERROR" "Red"
}

# Also try to stop any PowerShell processes that might be running port forwarding scripts
Write-Log "`nChecking for PowerShell processes running port forwarding scripts..." "INFO" "Cyan"

try {
    $powershellProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue
    $portForwardScriptProcesses = @()
    
    foreach ($process in $powershellProcesses) {
        try {
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            if ($commandLine -and ($commandLine -like "*port-forward-traefik*" -or $commandLine -like "*port-forward*")) {
                $portForwardScriptProcesses += $process
                Write-Log "Found port forwarding script process (PID: $($process.Id))" "INFO" "Yellow"
            }
        } catch {
            # Skip processes where we can't get command line
        }
    }
    
    if ($portForwardScriptProcesses.Count -gt 0) {
        Write-Log "Stopping $($portForwardScriptProcesses.Count) port forwarding script process(es)..." "INFO" "Cyan"
        
        foreach ($process in $portForwardScriptProcesses) {
            try {
                Stop-Process -Id $process.Id -Force
                Write-Log "Stopped script process PID: $($process.Id)" "SUCCESS" "Green"
            } catch {
                Write-Log "Failed to stop script process PID: $($process.Id) - $($_.Exception.Message)" "ERROR" "Red"
            }
        }
    } else {
        Write-Log "No port forwarding script processes found" "INFO" "Yellow"
    }
    
} catch {
    Write-Log "Error searching for PowerShell processes: $($_.Exception.Message)" "ERROR" "Red"
}

# Clean up any temporary port forwarding script files
Write-Log "`nCleaning up temporary files..." "INFO" "Cyan"

try {
    $tempScript = ".\Tools\port-forward-traefik.ps1"
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
        Write-Log "Removed temporary port forwarding script" "SUCCESS" "Green"
    }
} catch {
    Write-Log "Failed to remove temporary script: $($_.Exception.Message)" "WARNING" "Yellow"
}

# Verify no port forwarding is running
Write-Log "`nVerifying no port forwarding is running..." "INFO" "Cyan"

try {
    $remainingProcesses = Get-Process -Name "kubectl" -ErrorAction SilentlyContinue | Where-Object { 
        try {
            $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
            $commandLine -and $commandLine -like "*port-forward*"
        } catch {
            $false
        }
    }
    
    if ($remainingProcesses.Count -eq 0) {
        Write-Log "No port forwarding processes are running" "SUCCESS" "Green"
    } else {
        Write-Log "Warning: $($remainingProcesses.Count) port forwarding process(es) may still be running" "WARNING" "Yellow"
        foreach ($process in $remainingProcesses) {
            Write-Log "  PID: $($process.Id)" "WARNING" "Yellow"
        }
    }
} catch {
    Write-Log "Could not verify port forwarding status: $($_.Exception.Message)" "WARNING" "Yellow"
}

Write-Log "`nPort forwarding stop complete!" "SUCCESS" "Green"
Write-Log "All kubectl port forwarding processes have been stopped" "INFO" "Cyan"