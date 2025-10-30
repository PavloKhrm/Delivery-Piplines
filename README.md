### Prototype: Client Management Workflow
 Version Control

| Date       | Version | Author | Description                                                                |
| ---------- | ------- | ------ | -------------------------------------------------------------------------- |
| 26.09.2025 | 0.1     | Bill   | Initial draft: basic workflow with Minikube, client create/update/suspend. |
| 01.10.2025 | 0.2     | Bill   | Working instruction: switched to Kubernetes Kind, added detailed setup.    |

### Prerequisites
 - Docker Desktop for Windows: Must be installed and running.
 - KIND: Install KIND (the Chocolatey method is recommended: `choco install kind`).
 - Helm: The Kubernetes package manager.
 - kubectl: The Kubernetes command-line tool.

### ⚙️Setup Steps
1. Install Acrylic DNS Proxy (Windows only, This will store all client domains locally.)
 - Download and install Acrylic DNS Proxy.
 - Edit the hosts file:
 - Path: `C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicHosts.txt`
 - Add the line: `127.0.0.1 *.emitit.local`
 - Go to services and find 'Acrylic DNS Proxy' and click restart.

2. Configure the Network Adapter:
 - Open Network Connections (`Win + R`, then type `ncpa.cpl`).
 - Right-click to the active network (Wi-Fi or Ethernet) -> Properties.
 - Select Internet Protocol Version 4 (TCP/IPv4) -> Properties.
 - Set "Preferred DNS server" to: 127.0.0.1
 - Select Internet Protocol Version 6 (TCP/IPv6) -> Properties.
 - Set "Preferred DNS server" to: `::1`
 - Flush DNS Cache: Open PowerShell as Administrator and run `ipconfig /flushdns`.


3. Open the repo root (/basic-log) and create a cluster: `kind create cluster --config kind-config.yaml`

4. Follow this two steps strictly to ensure nothing weird happens - two steps ahead!
 - `helm install traefik traefik/traefik -f traefik-values.yaml`
 - `kubectl label namespace default ingress=allow`


## Working Instruction
### Suppose we create a new client named bill
1. Create a Client (open the terminal on path "\Delivery-Piplines\basic-blog>")
 - `.\new-client.bat bill` (for window)
 - `./new-client.sh bill` (for Mac/Linux)

2. Check a Client’s Containers
 - `kubectl get pods -n client-bill`

3. Stop (Suspend) One Client
 - `helm upgrade --install bill .\kind\charts\client-stack -n client-bill --set clientId=bill --set baseDomain=emitit.local --set suspended=true`

4. Resume / Update One Client
 - `helm upgrade --install bill .\kind\charts\client-stack -n client-bill --set clientId=bill --set baseDomain=emitit.local --set suspended=false`

5. Get Password for phpMyAdmin (for all clients, username is 'root')
 - `kubectl -n client-bill exec deploy/bill-phpmyadmin -- printenv MYSQL_ROOT_PASSWORD`

6. Get the .env file for a client
 - `kubectl get secret bill-envfile -n client-bill -o jsonpath='{.data.\.env}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }`

7. Edit the env file of the client (Change the application password)
- Step 1: Save the current .env  to a Local File by `kubectl get secret bill-envfile -n client-bill -o jsonpath='{.data.\.env}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } > .env.local` 
- Step 2: Edit the local file: `notepad .env.local`
- Step 3: `kubectl delete secret bill-envfile -n client-bill` (delete the Old secret)
- Step 4: `kubectl create secret generic bill-envfile -n client-bill --from-file=.env=.env.local` (create the new Secret)
- Last step: `kubectl rollout restart deployment yehmen-website -n client-yehmen` (Restart the Website Pod)

8. Delete the client
- `helm delete yehmen -n client-bill`

9. Change the ROOT password of a client
- Step 1: $pass = kubectl get secret bill-secrets -n client-bill -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}'
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pass))
- This could print something like w1sfEDXaadSEDada3k (remember the password when logging in MySQL credentials)
- Step 2: `kubectl exec -it statefulset/yehmen-mysql -n client-yehmen -- bash`
- Step 3: Log in to MySQL with the current password to change the password `mysql -u root -p`,
- Step 4: `ALTER USER 'root'@'%' IDENTIFIED BY 'mynewpassword';
FLUSH PRIVILEGES;
exit`
- Step 5: `exit` two times and encode with the new password: `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("mynewpassword"))`
- Step 6: `kubectl edit secret yehmen-secrets -n client-bill`
- Final Step: Restart phpMyAdmin with `kubectl rollout restart deployment/bill-phpmyadmin -n client-bill`


📝 Notes

Default phpmyadmin's username is root across all clients.

Use helm uninstall to fully remove a client’s stack.

Always update the Version Control table when changing this file.