# Multi-Tenant Kubernetes Blog System - Team Instructions

## Quick Start for Team Members

### Prerequisites
- Windows 10/11
- Administrator privileges (for first-time setup only)
- Internet connection

### One-Time Setup

1. **Download the repository**
   ```bash
   git clone <your-repo-url>
   cd Prototype_K8s_SecondAttempt
   ```

2. **Install prerequisites** (Run as Administrator)
   - Double-click `install-prerequisites.bat`
   - Wait for installation to complete
   - Restart your computer

3. **Start the system**
   - Double-click `start-system.bat`
   - The script will handle everything automatically
   - Wait for setup to complete

4. **Access the dashboard**
   - Open http://localhost:3001/multi-blog-dashboard.html
   - Start creating blogs!

### Daily Usage

1. **Start Docker Desktop** (if not already running)
2. **Run the system**
   - Double-click `start-system.bat`
   - Or run: `node command-runner.js`
3. **Access dashboard**
   - Open http://localhost:3001/multi-blog-dashboard.html

### After PC Restart

If your blog websites are not accessible after restarting your PC:

1. **Quick Fix (Recommended)**
   - Double-click `restore-after-restart.bat`
   - Wait for restoration to complete
   - Start dashboard: `node command-runner.js`

2. **Port Forwarding Only**
   - Double-click `fix-ports.bat`
   - This only fixes port forwarding issues

3. **Manual Steps**
   - Start Docker Desktop
   - Run `restore-after-restart.ps1`
   - Start dashboard: `node command-runner.js`

### Troubleshooting

#### PowerShell Execution Policy Issues
The `start-system.bat` script automatically handles this, but if you need to run PowerShell scripts manually:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### Docker Issues
- Ensure Docker Desktop is running
- Check that Kubernetes is enabled in Docker Desktop settings
- Restart Docker Desktop if needed

#### Port Conflicts
If port 8080 is in use:
```powershell
netstat -ano | findstr :8080
taskkill /PID <PID_NUMBER> /F
```

#### Reset Everything
```powershell
kind delete cluster --name k8s-blog-template
docker system prune -a
.\start-system.bat
```

### Team Workflow

#### Sharing Work
- Use Git to share code changes
- Use the backup system to share blog configurations
- Export Docker images for team sharing

#### Development
- Each team member runs their own local instance
- Use different client names to avoid conflicts
- Share configurations via the backup system

### Files for Team Members

- `install-prerequisites.bat` - Install all required tools (run as Administrator)
- `start-system.bat` - Start the system (handles all setup automatically)
- `restore-after-restart.bat` - **Restore system after PC restart** (most common use)
- `fix-ports.bat` - Fix port forwarding issues only
- `setup-team.bat` - Alternative setup method
- `TEAM-SETUP.md` - Detailed team setup guide
- `README.md` - Main documentation

### Support

If you encounter issues:
1. Check this README-TEAM.md
2. Review the main README.md
3. Check the GUIDE.md for detailed instructions
4. Contact the team lead for assistance

## Alternative Setup Methods

### Method 1: Automated (Recommended)
Use `start-system.bat` - handles everything automatically

### Method 2: Manual PowerShell
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
.\setup-fresh-machine.ps1
node command-runner.js
```

### Method 3: Docker Compose (Future)
A Docker Compose setup is planned for even easier team deployment.

## System Requirements

- **OS**: Windows 10/11
- **RAM**: 8GB+ recommended
- **Disk**: 50GB+ free space
- **Network**: Internet connection for initial setup
