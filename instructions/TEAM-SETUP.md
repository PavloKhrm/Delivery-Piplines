# Team Setup Guide - Multi-Tenant Kubernetes Blog System

## Quick Start for Team Members

### Prerequisites
- Windows 10/11
- Administrator privileges (for initial setup)
- Internet connection

### Option 1: Automated Setup (Recommended)

1. **Download the repository**
   ```bash
   git clone <your-repo-url>
   cd Prototype_K8s_SecondAttempt
   ```

2. **Run as Administrator**
   - Right-click on `install-prerequisites.bat`
   - Select "Run as administrator"
   - Wait for installation to complete
   - Restart your computer

3. **Start the system**
   - Double-click `setup-team.bat`
   - Follow the prompts
   - Wait for setup to complete

4. **Access the dashboard**
   - Open http://localhost:3001/multi-blog-dashboard.html
   - Start creating blogs!

### Option 2: Manual Setup

If the automated setup doesn't work, follow these steps:

1. **Install Chocolatey** (as Administrator)
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

2. **Install prerequisites**
   ```powershell
   choco install docker-desktop kubernetes-cli kind kubernetes-helm nodejs npm git -y
   ```

3. **Set PowerShell execution policy**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```

4. **Run the setup script**
   ```powershell
   .\setup-fresh-machine.ps1
   ```

## Troubleshooting

### PowerShell Execution Policy Issues
If you get execution policy errors:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Docker Desktop Issues
- Ensure Docker Desktop is running
- Check that Kubernetes is enabled in Docker Desktop settings
- Restart Docker Desktop if needed

### Port Conflicts
If port 8080 is in use:
```powershell
netstat -ano | findstr :8080
# Kill the process using the PID shown
taskkill /PID <PID_NUMBER> /F
```

### Kind Cluster Issues
If the Kind cluster fails to create:
```powershell
kind delete cluster --name k8s-blog-template
.\setup-fresh-machine.ps1
```

## Team Workflow

### Daily Usage
1. Start Docker Desktop
2. Run `node command-runner.js` to start the dashboard
3. Access http://localhost:3001/multi-blog-dashboard.html
4. Create and manage blogs as needed

### Sharing Work
- Use the backup/restore system to share blog configurations
- Export Docker images for team sharing
- Use Git to share code changes

### Development
- Each team member can run their own local instance
- Use different client names to avoid conflicts
- Share configurations via the backup system

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the main README.md
3. Check the GUIDE.md for detailed instructions
4. Contact the team lead for assistance

## Files for Team Members

- `install-prerequisites.bat` - Install all required tools
- `setup-team.bat` - Run the complete setup
- `setup-fresh-machine.ps1` - Main setup script
- `README.md` - Main documentation
- `GUIDE.md` - Detailed setup guide
