const express = require('express');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 3001;
const staticRoot = __dirname;

app.use(express.json());
app.use(express.static(staticRoot));

app.post('/run-command', (req, res) => {
    const { command } = req.body;
    
    if (!command) {
        return res.status(400).json({ error: 'No command provided' });
    }

    console.log(`Executing: ${command}`);
    
    exec(command, { 
        cwd: path.resolve(staticRoot, '..'),
        shell: 'powershell.exe',
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    }, (error, stdout, stderr) => {
        const output = stdout + stderr;
        
        if (error) {
            console.error(`Command failed: ${error.message}`);
            console.error(`Output: ${output}`);
            return res.status(500).json({ 
                error: error.message, 
                output: output 
            });
        }
        
        console.log(`Command completed successfully`);
        res.json({ output: output });
    });
});

app.listen(PORT, () => {
    console.log(`Command runner server running on http://localhost:${PORT}`);
    console.log(`Multi-blog dashboard available at http://localhost:${PORT}/multi-blog-dashboard.html`);
});
