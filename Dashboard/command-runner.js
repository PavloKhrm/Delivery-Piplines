const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3001;
const staticRoot = __dirname;

// Ensure logs directory exists
const logsDir = path.resolve(staticRoot, '..', 'logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(staticRoot));

// Logging function with rotation
function logToFile(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] [${level}] ${message}\n`;
    const logFile = path.join(logsDir, 'dashboard-commands.log');
    
    try {
        // Check if log file is too large (5MB) and rotate if needed
        if (fs.existsSync(logFile)) {
            const stats = fs.statSync(logFile);
            if (stats.size > 5 * 1024 * 1024) { // 5MB
                const backupFile = path.join(logsDir, `dashboard-commands-${Date.now()}.log`);
                fs.renameSync(logFile, backupFile);
                
                // Keep only last 3 backup files
                const files = fs.readdirSync(logsDir)
                    .filter(file => file.startsWith('dashboard-commands-') && file.endsWith('.log'))
                    .sort()
                    .reverse();
                
                if (files.length > 3) {
                    files.slice(3).forEach(file => {
                        fs.unlinkSync(path.join(logsDir, file));
                    });
                }
            }
        }
        
        fs.appendFileSync(logFile, logEntry);
        console.log(`[${level}] ${message}`);
    } catch (error) {
        console.error('Failed to write to log file:', error.message);
    }
}

app.post('/run-command', (req, res) => {
    const { command } = req.body;
    
    if (!command) {
        logToFile('No command provided in request', 'ERROR');
        return res.status(400).json({ error: 'No command provided' });
    }

    logToFile(`Executing command: ${command}`, 'INFO');
    
    exec(command, { 
        cwd: path.resolve(staticRoot, '..'),
        shell: 'powershell.exe',
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    }, (error, stdout, stderr) => {
        const output = stdout + stderr;
        
        if (error) {
            logToFile(`Command failed: ${error.message}`, 'ERROR');
            logToFile(`Command output: ${output}`, 'ERROR');
            return res.status(500).json({ 
                error: error.message, 
                output: output 
            });
        }
        
        logToFile(`Command completed successfully`, 'SUCCESS');
        logToFile(`Command output: ${output}`, 'DEBUG');
        res.json({ output: output });
    });
});

// New endpoint to get log contents with truncation
app.get('/logs', (req, res) => {
    const logFile = path.join(logsDir, 'dashboard-commands.log');
    
    try {
        if (fs.existsSync(logFile)) {
            const stats = fs.statSync(logFile);
            const fileSize = stats.size;
            
            // If file is larger than 1MB, read only the last 500KB
            let logs;
            if (fileSize > 1024 * 1024) { // 1MB
                const fd = fs.openSync(logFile, 'r');
                const bufferSize = 512 * 1024; // 500KB
                const buffer = Buffer.alloc(bufferSize);
                fs.readSync(fd, buffer, 0, bufferSize, fileSize - bufferSize);
                fs.closeSync(fd);
                logs = buffer.toString('utf8');
                
                // Find the first complete line
                const firstNewline = logs.indexOf('\n');
                if (firstNewline > 0) {
                    logs = logs.substring(firstNewline + 1);
                }
                
                logs = `... [TRUNCATED - showing last ${Math.round(bufferSize/1024)}KB of ${Math.round(fileSize/1024)}KB total] ...\n\n` + logs;
            } else {
                logs = fs.readFileSync(logFile, 'utf8');
            }
            
            res.json({ logs: logs });
        } else {
            res.json({ logs: 'No logs available yet.' });
        }
    } catch (error) {
        logToFile(`Failed to read logs: ${error.message}`, 'ERROR');
        res.status(500).json({ error: 'Failed to read logs' });
    }
});

// Route for modern dashboard (default)
app.get('/', (req, res) => {
    res.sendFile(path.join(staticRoot, 'modern-blog-dashboard.html'));
});

// Legacy route for old dashboard
app.get('/legacy', (req, res) => {
    res.sendFile(path.join(staticRoot, 'multi-blog-dashboard.html'));
});

// API endpoint for blogs (HTMX)
app.get('/api/blogs', (req, res) => {
    const namespacesCmd = `kubectl get namespaces -o json`;
    
    exec(namespacesCmd, { 
        cwd: path.resolve(staticRoot, '..'),
        shell: 'powershell.exe',
        maxBuffer: 1024 * 1024 * 10
    }, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).send('<div class="loading"><span>Error loading blogs</span></div>');
        }
        
        try {
            const allNamespacesData = JSON.parse(stdout);
            const namespaces = allNamespacesData.items.filter(ns => ns.metadata.name.startsWith('blog-'));
            
            if (namespaces.length === 0) {
                return res.send('<div class="loading"><span>No blogs found. Create your first blog!</span></div>');
            }
            
            // Get pods for first namespace as example (in real implementation, you'd get all)
            const firstNamespace = namespaces[0].metadata.name;
            const podsCmd = `kubectl get pods -n ${firstNamespace} -o json`;
            
            exec(podsCmd, { 
                cwd: path.resolve(staticRoot, '..'),
                shell: 'powershell.exe',
                maxBuffer: 1024 * 1024 * 10
            }, (podError, podStdout, podStderr) => {
                if (podError) {
                    return res.status(500).send('<div class="loading"><span>Error loading blog details</span></div>');
                }
                
                try {
                    const pods = JSON.parse(podStdout).items;
                    const clientName = firstNamespace.replace('blog-', '').replace(/-dev$|^-staging$|^-production$/, '');
                    const domain = `${clientName}.emit-it.local`;
                    const totalPods = pods.length;
                    const runningPods = pods.filter(pod => pod.status.phase === 'Running').length;
                    const status = runningPods === totalPods ? 'running' : 'pending';
                    
                    const blogCard = `
                        <div class="blog-card fade-in">
                            <div class="blog-header">
                                <div>
                                    <div class="blog-name">${clientName}</div>
                                </div>
                                <div class="blog-status status-${status}">${status}</div>
                            </div>
                            <div class="blog-info">
                                <div class="blog-info-item">
                                    <span class="blog-info-label">Namespace:</span>
                                    <span class="blog-info-value">${firstNamespace}</span>
                                </div>
                                <div class="blog-info-item">
                                    <span class="blog-info-label">Pods:</span>
                                    <span class="blog-info-value">${runningPods}/${totalPods}</span>
                                </div>
                                <div class="blog-info-item">
                                    <span class="blog-info-label">Domain:</span>
                                    <span class="blog-info-value">${domain}</span>
                                </div>
                                <div class="blog-info-item">
                                    <span class="blog-info-label">Age:</span>
                                    <span class="blog-info-value">${formatDuration(new Date() - new Date(pods[0]?.metadata?.creationTimestamp || new Date()))}</span>
                                </div>
                            </div>
                            <div class="blog-actions">
                                <a href="https://${domain}:8443" target="_blank" class="btn btn-primary btn-sm">
                                    <span>🌐</span>
                                    <span>Visit</span>
                                </a>
                                <button class="btn btn-secondary btn-sm" onclick="scaleBlog('${firstNamespace}', 'backend')">
                                    <span>📈</span>
                                    <span>Scale Backend</span>
                                </button>
                                <button class="btn btn-secondary btn-sm" onclick="scaleBlog('${firstNamespace}', 'frontend')">
                                    <span>📈</span>
                                    <span>Scale Frontend</span>
                                </button>
                                <button class="btn btn-danger btn-sm" onclick="deleteBlog('${firstNamespace}')">
                                    <span>🗑️</span>
                                    <span>Delete</span>
                                </button>
                            </div>
                        </div>
                    `;
                    
                    res.send(blogCard);
                } catch (parseError) {
                    res.status(500).send('<div class="loading"><span>Error parsing blog data</span></div>');
                }
            });
        } catch (parseError) {
            res.status(500).send('<div class="loading"><span>Error parsing namespace data</span></div>');
        }
    });
});

// API endpoint for creating blogs (HTMX)
app.post('/api/create-blog', (req, res) => {
    console.log('Request body:', req.body);
    console.log('Request headers:', req.headers);
    
    const clientName = req.body.clientName;
    const environment = req.body.environment || 'dev';
    const replicas = req.body.replicas || '1';
    
    if (!clientName) {
        return res.status(400).send('<span>❌</span><span>Please enter a blog name</span>');
    }

    if (!/^[a-z0-9][a-z0-9\-]*[a-z0-9]$/.test(clientName)) {
        return res.status(400).send('<span>❌</span><span>Blog name must be lowercase, alphanumeric, and can contain hyphens</span>');
    }

    logToFile(`Creating new blog: ${clientName}`, 'INFO');
    
    // Generate client deployment with wildcard domain pattern
    const domain = `${clientName}.emit-it.local`;
    const generateCmd = `powershell -ExecutionPolicy Bypass -File "template-generator/Generate-ClientDeployment.ps1" -ClientName "${clientName}" -Domain "${domain}" -Environment "${environment}" -Force`;
    
    exec(generateCmd, { 
        cwd: path.resolve(staticRoot, '..'),
        shell: 'powershell.exe',
        maxBuffer: 1024 * 1024 * 10
    }, (error, stdout, stderr) => {
        if (error) {
            logToFile(`Error generating deployment: ${error.message}`, 'ERROR');
            return res.status(500).send('<span>❌</span><span>Error generating deployment</span>');
        }
        
        // Deploy the new blog
        const deployCmd = `powershell -ExecutionPolicy Bypass -File "deployments/${clientName}/deploy.ps1" -Force`;
        
        exec(deployCmd, { 
            cwd: path.resolve(staticRoot, '..'),
            shell: 'powershell.exe',
            maxBuffer: 1024 * 1024 * 10
        }, (deployError, deployStdout, deployStderr) => {
            if (deployError) {
                logToFile(`Error deploying blog: ${deployError.message}`, 'ERROR');
                return res.status(500).send('<span>❌</span><span>Error deploying blog</span>');
            }
            
            logToFile(`Blog "${clientName}" created successfully`, 'SUCCESS');
            res.send(`<span>✅</span><span>Blog "${clientName}" created successfully! Visit: https://${domain}:8443</span>`);
        });
    });
});

// Helper function for duration formatting
function formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d`;
    if (hours > 0) return `${hours}h`;
    if (minutes > 0) return `${minutes}m`;
    return `${seconds}s`;
}

app.listen(PORT, () => {
    console.log(`Command runner server running on http://localhost:${PORT}`);
    console.log(`Modern dashboard available at http://localhost:${PORT}/`);
    console.log(`Legacy dashboard available at http://localhost:${PORT}/legacy`);
});
