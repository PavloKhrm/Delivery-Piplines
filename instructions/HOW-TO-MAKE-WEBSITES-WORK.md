# How to Make Your Local Blog Websites Work

## The Problem
After deploying new blogs, you get domains like:
- `dont-altf4.emit-it.local`
- `pavlo.emit-it.local` 
- `test.emit-it.local`

But when you try to access them, they don't work.

## The Simple Solution

### Option 1: Run the Fix Script (Recommended)
```bash
# Run this ONE command as Administrator
.\Tools\fix-local-websites.ps1
```

This script will:
1. Stop any existing port forwarding
2. Start Traefik port forwarding
3. Update your Windows hosts file
4. Show you the working URLs

### Option 2: Manual Steps

#### Step 1: Start Port Forwarding
```bash
# Stop any existing port forwarding
Get-Job | Stop-Job; Get-Job | Remove-Job

# Start Traefik port forwarding
kubectl port-forward -n traefik-system service/traefik 8080:8080 8443:443
```

#### Step 2: Update Windows Hosts File
1. Open Notepad as Administrator
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Add these lines at the end:
```
127.0.0.1 dont-altf4.emit-it.local
127.0.0.1 pavlo.emit-it.local
127.0.0.1 test.emit-it.local
```
4. Save the file

#### Step 3: Access Your Websites
Open your browser and go to:
- `https://dont-altf4.emit-it.local:8443/`
- `https://pavlo.emit-it.local:8443/`
- `https://test.emit-it.local:8443/`

## Important Notes

### SSL Warning is Normal
Your browser will show a security warning because these are local domains with self-signed certificates. This is normal and safe for local development.

**To proceed:**
1. Click "Advanced" or "Show details"
2. Click "Proceed to website" or "Accept risk and continue"

### If Websites Still Don't Work
1. **Restart your browser** after updating the hosts file
2. **Check if port forwarding is running:**
   ```bash
   Get-Job
   ```
3. **Check your domains:**
   ```bash
   kubectl get ingress -A
   ```

## Quick Commands

### Check What's Running
```bash
# See all your blog namespaces
kubectl get namespaces | findstr blog

# See all your domains
kubectl get ingress -A

# Check port forwarding status
Get-Job
```

### Start Dashboard
```bash
cd Dashboard
node command-runner.js
```
Then open: `http://localhost:3001/multi-blog-dashboard.html`

### Stop Everything
```bash
# Stop port forwarding
Get-Job | Stop-Job; Get-Job | Remove-Job

# Stop dashboard (Ctrl+C in the dashboard window)
```

## Troubleshooting

### "This site can't be reached"
- Make sure port forwarding is running: `Get-Job`
- Check if domains are in hosts file
- Restart browser

### "Connection refused"
- Run the fix script again
- Check if Traefik is running: `kubectl get pods -n traefik-system`

### "SSL Certificate Error"
- This is normal for local domains
- Click "Advanced" → "Proceed to website"

## Summary
**To make your websites work:**
1. Run `.\Tools\fix-local-websites.ps1` as Administrator
2. Open `https://your-domain.emit-it.local:8443/` in browser
3. Click "Advanced" → "Proceed" when you see SSL warning

That's it! Your local blog websites should now work.
