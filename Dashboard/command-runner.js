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
app.use(express.static(staticRoot));

// Logging function
function logToFile(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] [${level}] ${message}\n`;
    const logFile = path.join(logsDir, 'dashboard-commands.log');
    
    try {
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

// New endpoint to get log contents
app.get('/logs', (req, res) => {
    const logFile = path.join(logsDir, 'dashboard-commands.log');
    
    try {
        if (fs.existsSync(logFile)) {
            const logs = fs.readFileSync(logFile, 'utf8');
            res.json({ logs: logs });
        } else {
            res.json({ logs: 'No logs available yet.' });
        }
    } catch (error) {
        logToFile(`Failed to read logs: ${error.message}`, 'ERROR');
        res.status(500).json({ error: 'Failed to read logs' });
    }
});

app.listen(PORT, () => {
    console.log(`Command runner server running on http://localhost:${PORT}`);
    console.log(`Multi-blog dashboard available at http://localhost:${PORT}/multi-blog-dashboard.html`);
});
