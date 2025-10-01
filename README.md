### Prototype: Client Management Workflow
 Version Control

| Date       | Version | Author | Description                                                                |
| ---------- | ------- | ------ | -------------------------------------------------------------------------- |
| 26.09.2025 | 0.1     | Bill   | Initial draft: basic workflow with Minikube, client create/update/suspend. |
| 01.10.2025 | 0.2     | Bill   | Working instruction: switched to Kubernetes Kind, added detailed setup.    |

### Prerequisites
 - Docker Desktop for Windows: Must be installed and running.
 - KIND: Install KIND (the Chocolatey method is recommended: **choco install kind**).
 - Helm: The Kubernetes package manager.
 - kubectl: The Kubernetes command-line tool.

### ⚙️Setup Steps
1. Install Acrylic DNS Proxy (Windows only, This will store all client domains locally.)
 - Download and install Acrylic DNS Proxy.
 - Edit the hosts file:
 - Path: C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicHosts.txt
 - Add the line: 127.0.0.1 *.emitit.local
 - Restart Acrylic Service: Search “Restart Acrylic Service” in Start Menu.

3. Configure Your Network Adapter:

 - Open Network Connections (Win + R, then type ncpa.cpl).

 - Right-click your active network (Wi-Fi or Ethernet) -> Properties.

 - Select Internet Protocol Version 4 (TCP/IPv4) -> Properties.

 - Set "Preferred DNS server" to: 127.0.0.1

 - Select Internet Protocol Version 6 (TCP/IPv6) -> Properties.

 - Set "Preferred DNS server" to: ::1

 - Flush DNS Cache: Open PowerShell as Administrator and run ipconfig /flushdns.


4. Open the repo root (/basic-log) and create a cluster: **kind create cluster --config kind-config.yaml**

5. Install Traefik
 - Open the terminal
 - **helm repo add traefik https://traefik.github.io/charts**
 - **helm repo update**
 - **helm install traefik traefik/traefik -f traefik-values.yaml**

6. Allow Ingress Traffic
 - Open the terminal
 - **kubectl label namespace default ingress=allow**


## Working Instruction
2. Create a Client (open the terminal on path "\Delivery-Piplines\basic-blog>")
 - .\new-client.bat bill (for window)
 - ./new-client.sh bill (for Mac/Linux)

3. Update a Client
 - "helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=demo.local"

4. Check a Client’s Containers
 - "kubectl get pods -n client-bill -o jsonpath="{range .items[*]}{.metadata.name}{': '}{range .spec.initContainers[*]}{.name}{' (init) '}{end}{range .spec.containers[*]}{.name}{' '}{end}{'\n'}{end}"

5. Stop (Suspend) One Client
 - "helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=emitit.local --set suspended=true"

6. Resume One Client
 - "helm upgrade --install bill .\k8s\charts\client-stack -n client-bill `
  --set clientId=bill --set baseDomain=emitit.local --set suspended=false"

7. Get Password for phpMyAdmin (for all clients, username is 'root')
 - "kubectl -n client-bill exec deploy/bill-phpmyadmin -- printenv MYSQL_ROOT_PASSWORD"

📝 Notes

Default phpmyadmin's username is root across all clients.

Use helm uninstall to fully remove a client’s stack.

Always update the Version Control table when changing this file.