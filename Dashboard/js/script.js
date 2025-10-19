let allBlogs = [];
let currentSection = 'overview';

document.addEventListener('DOMContentLoaded', function() {
    showSection('overview');
    updateDomainPreview();
    fetchAllBlogs();
    initializeCommandPanel();
    setupAutoscrollListener();
});

function showSection(sectionName) {
    document.querySelectorAll('.section').forEach(section => {
        section.style.display = 'none';
    });

    document.getElementById(`${sectionName}-section`).style.display = 'block';

    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    document.querySelector(`[onclick="showSection('${sectionName}')"]`)?.classList.add('active');
    document.querySelector(`[onclick="openCreateModal()"]`)?.classList.remove('active');

    const titles = {
        'overview': 'Dashboard Overview',
        'clients': 'All clients',
        'logs': 'System Logs'
    };
    document.getElementById('page-title').textContent = titles[sectionName] || 'Client Manager';

    currentSection = sectionName;
}

function openCreateModal() {
    document.getElementById('create-modal').classList.add('show');
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    document.querySelector(`[onclick="openCreateModal()"]`)?.classList.add('active');
}

function closeModal(event) {
    if (event && event.target !== event.currentTarget) return;
    const modal = document.getElementById('create-modal');
    modal.classList.remove('show');
    
    const form = modal.querySelector('form');
    if (form) {
        form.reset();
    }
    document.getElementById('client-name').value = '';
    updateDomainPreview();
    
    const statusMessage = document.getElementById('status-message');
    if (statusMessage) {
        statusMessage.classList.remove('show');
    }
}

function updateDomainPreview() {
    const clientName = document.getElementById('client-name').value.trim();
    const preview = clientName ? `${clientName}.emitit.com` : '[client-name].emitit.com';
    document.getElementById('domain-preview').value = preview;
}

async function fetchAllBlogs() {
    try {
        const namespacesCmd = `kubectl get namespaces -o json`;
        const namespacesResponse = await fetch('/run-command', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ command: namespacesCmd })
        });
        const namespacesData = await namespacesResponse.json();
        
        if (namespacesResponse.ok && namespacesData.output) {
            const allNamespacesData = JSON.parse(namespacesData.output);
            const namespaces = allNamespacesData.items.filter(ns => ns.metadata.name.startsWith('client-'));
            
            const allBlogsData = [];
            for (const ns of namespaces) {
                const namespace = ns.metadata.name;
                const podsCmd = `kubectl get pods -n ${namespace} -o json`;
                const podsResponse = await fetch('/run-command', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command: podsCmd })
                });
                const podsData = await podsResponse.json();
                
                if (podsResponse.ok && podsData.output) {
                    const pods = JSON.parse(podsData.output).items;
                    const clientName = namespace.replace('client-', '').replace(/-dev$|^-staging$|^-production$/, '');
                    const domain = `${clientName}.emitit.local`;
                    
                    allBlogsData.push({
                        namespace: namespace,
                        pods: pods,
                        clientName: clientName,
                        domain: domain
                    });
                }
            }
            
            allBlogs = allBlogsData;
            renderBlogs();
            updateStats();
        }
    } catch (error) {
        showStatusMessage(`Error fetching blogs: ${error.message}`, 'error');
    }
}

function renderBlogs() {
    const blogsContainer = currentSection === 'overview' ? 'recent-blogs' : 'all-blogs';
    const container = document.getElementById(blogsContainer);
    
    if (allBlogs.length === 0) {
        container.innerHTML = '<div class="loading"><span>No client found. Create your first client!</span></div>';
        return;
    }

    const blogsToShow = currentSection === 'overview' ? allBlogs.slice(0, 4) : allBlogs;
    
    container.innerHTML = blogsToShow.map(blog => {
        const totalPods = blog.pods.length;
        const runningPods = blog.pods.filter(pod => pod.status.phase === 'Running').length;
        const status = runningPods === totalPods ? 'running' : 'pending';
        
        return `
            <div class="blog-card fade-in">
                <div class="blog-header">
                    <div>
                        <div class="blog-name">${blog.clientName}</div>
                    </div>
                    <div class="blog-status status-${status}">${status}</div>
                </div>
                <div class="blog-info">
                    <div class="blog-info-item">
                        <span class="blog-info-label">Namespace:</span>
                        <span class="blog-info-value">${blog.namespace}</span>
                    </div>
                    <div class="blog-info-item">
                        <span class="blog-info-label">Pods:</span>
                        <span class="blog-info-value">${runningPods}/${totalPods}</span>
                    </div>
                    <div class="blog-info-item">
                        <span class="blog-info-label">Domain:</span>
                        <span class="blog-info-value">${blog.domain}</span>
                    </div>
                    <div class="blog-info-item">
                        <span class="blog-info-label">Age:</span>
                        <span class="blog-info-value">${formatDuration(new Date() - new Date(blog.pods[0]?.metadata?.creationTimestamp || new Date()))}</span>
                    </div>
                </div>
                <div class="blog-actions">
                    <a href="http://${blog.domain}" target="_blank" class="btn btn-primary btn-sm">
                        <span>🌐</span>
                        <span>Visit</span>
                    </a>
                    <button class="btn btn-danger btn-sm" onclick="deleteBlog('${blog.namespace}')">
                        <span>🗑️</span>
                        <span>Delete</span>
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function updateStats() {
    const totalBlogs = allBlogs.length;
    const runningBlogs = allBlogs.filter(blog => 
        blog.pods.filter(pod => pod.status.phase === 'Running').length === blog.pods.length
    ).length;
    const totalPods = allBlogs.reduce((sum, blog) => sum + blog.pods.length, 0);

    document.getElementById('total-blogs').textContent = totalBlogs;
    document.getElementById('running-blogs').textContent = runningBlogs;
    document.getElementById('total-pods').textContent = totalPods;
    document.getElementById('total-namespaces').textContent = totalBlogs;
}

async function scaleBlog(namespace, service) {
    const replicas = prompt(`How many ${service} pods do you want?`, "2");
    if (replicas && !isNaN(replicas)) {
        try {
            const cmd = `kubectl scale deployment ${namespace}-blog-template-${service} -n ${namespace} --replicas=${replicas}`;
            await runCommand(cmd);
            showStatusMessage(`Scaled ${service} to ${replicas} pods`, "success");
            fetchAllBlogs();
        } catch (error) {
            showStatusMessage(`Error scaling: ${error.message}`, "error");
        }
    }
}

async function deleteBlog(namespace) {
    if (confirm(`Are you sure you want to delete the client in namespace "${namespace}"? This will remove all data!`)) {
        try {
            const response = await fetch('/api/delete-blog', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ namespace: namespace })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to delete client');
            }

            logCommand(`kubectl delete namespace ${namespace}`, 'Command executed via secure API.');

            showStatusMessage(`Client "${namespace}" deleted`, "success");
            fetchAllBlogs();

        } catch (error) {
            showStatusMessage(`Error deleting: ${error.message}`, "error");
        }
    }
}

async function refreshLogs() {
    updateCommandStatus('warning', 'Refreshing Logs...');
    
    try {
        const response = await fetch('/logs');
        const data = await response.json();
        
        if (response.ok) {
            const logsContainer = document.getElementById('command-logs');
            logsContainer.textContent = data.logs || 'No logs available yet.';
            
            if (document.getElementById('autoscroll-checkbox').checked) {
                logsContainer.scrollTop = logsContainer.scrollHeight;
            }
            
            updateCommandStatus('ready', 'Logs Updated');
        } else {
            updateCommandStatus('error', 'Failed to Load Logs');
        }
    } catch (error) {
        updateCommandStatus('error', 'Logs Error');
    }
    
    updateLastUpdated();
}

async function clearLogs() {
    if (confirm('Are you sure you want to clear all logs? This cannot be undone.')) {
        try {
            await runCommand('Remove-Item -Path "logs\\dashboard-commands.log" -Force -ErrorAction SilentlyContinue');
            refreshLogs();
            showStatusMessage("Logs cleared successfully", "success");
        } catch (error) {
            showStatusMessage("Failed to clear logs: " + error.message, "error");
        }
    }
}

function refreshData() {
    showStatusMessage("Refreshing data...", "info");
    fetchAllBlogs();
    refreshLogs();
}

async function runCommand(cmd) {
    try {
        updateCommandStatus('warning', 'Executing Command...');
        
        logCommand(cmd, 'Executing...');
        
        const response = await fetch('/run-command', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ command: cmd })
        });
        const data = await response.json();
        
        const commandOutput = document.getElementById('command-output');
        const lastEntry = commandOutput.textContent.lastIndexOf('Executing...');
        if (lastEntry !== -1) {
            const beforeExecuting = commandOutput.textContent.substring(0, lastEntry);
            const afterExecuting = commandOutput.textContent.substring(lastEntry + 'Executing...'.length);
            const timestamp = new Date().toLocaleString();
            
            commandOutput.textContent = beforeExecuting + 
                `[${timestamp}] $ ${cmd}
${data.output || data.error || 'No output'}
${'='.repeat(80)}

` + afterExecuting;
            
            if (document.getElementById('autoscroll-checkbox').checked) {
                commandOutput.scrollTop = commandOutput.scrollHeight;
            }
        }
        
        if (!response.ok) {
            updateCommandStatus('error', 'Command Failed');
            throw new Error(data.error || 'Unknown error');
        }
        
        updateCommandStatus('ready', 'Command Completed');
        return data;
    } catch (error) {
        updateCommandStatus('error', 'Command Error');
        throw error;
    }
}

function showStatusMessage(message, type) {
    const statusMessage = document.getElementById('status-message');
    const statusIcon = document.getElementById('status-icon');
    const statusText = document.getElementById('status-text');
    
    const icons = {
        'success': '✅',
        'error': '❌',
        'warning': '⚠️',
        'info': 'ℹ️'
    };
    
    statusIcon.textContent = icons[type] || 'ℹ️';
    statusText.textContent = message;
    
    statusMessage.className = `status-message show ${type}`;
    
    setTimeout(() => {
        statusMessage.classList.remove('show');
    }, 5000);
}

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

function initializeCommandPanel() {
    updateCommandStatus('ready', 'System Ready');
    updateLastUpdated();
    
    setTimeout(() => {
        document.getElementById('command-panel').classList.add('expanded');
    }, 1000);
}

function setupAutoscrollListener() {
    const checkbox = document.getElementById('autoscroll-checkbox');
    const label = document.querySelector('.autoscroll-label');
    
    if (checkbox && label) {
        checkbox.addEventListener('click', function(event) {
            event.stopPropagation();
        });
        
        label.addEventListener('click', function(event) {
            event.stopPropagation();
            checkbox.checked = !checkbox.checked;
        });
    }
}

function toggleCommandPanel() {
    const panel = document.getElementById('command-panel');
    const icon = document.getElementById('panel-toggle-icon');
    
    panel.classList.toggle('expanded');
    icon.textContent = panel.classList.contains('expanded') ? '▼' : '▲';
}

function switchCommandTab(tabName) {
    document.querySelectorAll('.command-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    event.target.classList.add('active');
    
    document.getElementById('command-logs').style.display = tabName === 'logs' ? 'block' : 'none';
    document.getElementById('command-output').style.display = tabName === 'commands' ? 'block' : 'none';
    
    if (document.getElementById('autoscroll-checkbox').checked) {
        const activeOutput = tabName === 'logs' ? 
            document.getElementById('command-logs') : 
            document.getElementById('command-output');
        setTimeout(() => {
            activeOutput.scrollTop = activeOutput.scrollHeight;
        }, 100);
    }
}

function updateCommandStatus(status, message) {
    const indicator = document.getElementById('status-indicator');
    const statusText = document.getElementById('status-text');
    
    indicator.className = `status-indicator ${status}`;
    statusText.textContent = message;
}

function updateLastUpdated() {
    const lastUpdated = document.getElementById('last-updated');
    lastUpdated.textContent = `Last updated: ${new Date().toLocaleTimeString()}`;
}

function logCommand(command, output) {
    const commandOutput = document.getElementById('command-output');
    const timestamp = new Date().toLocaleString();
    
    const logEntry = `
[${timestamp}] $ ${command}
${output}
${'='.repeat(80)}

`;
    
    commandOutput.textContent += logEntry;
    
    if (document.getElementById('autoscroll-checkbox').checked) {
        setTimeout(() => {
            commandOutput.scrollTop = commandOutput.scrollHeight;
        }, 100);
    }
    
    document.querySelectorAll('.command-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    const commandsTab = document.querySelector('[onclick="switchCommandTab(\'commands\')"]');
    if (commandsTab) {
        commandsTab.classList.add('active');
    }
    
    document.getElementById('command-logs').style.display = 'none';
    commandOutput.style.display = 'block';
    
    updateCommandStatus('ready', 'Command Executed');
    updateLastUpdated();
}

document.body.addEventListener('htmx:beforeRequest', function(evt) {
    if (evt.detail.pathInfo.requestPath.includes('/api/create-blog')) {
        console.log('Starting blog creation...');
        updateCommandStatus('warning', 'Creating Blog...');
    }
});

document.body.addEventListener('htmx:afterRequest', function(evt) {
    console.log('HTMX afterRequest:', evt.detail.xhr.status, evt.detail.pathInfo.requestPath);
    
    if (evt.detail.pathInfo.requestPath.includes('/api/create-blog')) {
        if (evt.detail.xhr.status === 200) {
            console.log('Blog created successfully!');
            showStatusMessage("Blog created successfully!", "success");
            updateCommandStatus('ready', 'Blog Created');
            
            closeModal();
            
            setTimeout(() => {
                fetchAllBlogs();
                refreshLogs();
            }, 2000);
        } else {
            console.log('Blog creation failed:', evt.detail.xhr.status);
            showStatusMessage("Error creating blog: " + evt.detail.xhr.responseText, "error");
            updateCommandStatus('error', 'Blog Creation Failed');
        }
    }
    
    if (evt.detail.pathInfo.requestPath.includes('/logs')) {
        const logsContainer = document.getElementById('command-logs');
        if (logsContainer && document.getElementById('autoscroll-checkbox').checked) {
            setTimeout(() => {
                logsContainer.scrollTop = logsContainer.scrollHeight;
            }, 100);
        }
    }
});

document.body.addEventListener('htmx:responseError', function(evt) {
    console.log('HTMX responseError:', evt.detail);
    if (evt.detail.pathInfo.requestPath.includes('/api/create-blog')) {
        showStatusMessage("Error creating client: " + evt.detail.xhr.responseText, "error");
        updateCommandStatus('error', 'Blog Creation Error');
    }
});

document.addEventListener('DOMContentLoaded', function() {
    const createForm = document.querySelector('#create-modal form');
    if (createForm) {
        createForm.addEventListener('submit', function(e) {
            console.log('Form submitted via direct event listener');
            setTimeout(() => {
                const modal = document.getElementById('create-modal');
                if (modal && modal.classList.contains('show')) {
                    console.log('Fallback: Closing modal manually');
                    closeModal();
                    showStatusMessage("Blog creation initiated", "info");
                }
            }, 5000);
        });
    }
});

/*
setInterval(() => {
    if (currentSection === 'overview' || currentSection === 'blogs') {
        fetchAllBlogs();
    }
}, 30000);
*/