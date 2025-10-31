### Prototype: Client Management Workflow
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

# Hetzner K8s Dashboard — concise README

**What it is.**
A tiny control panel that spins up k3s control-planes and worker nodes on Hetzner Cloud, wires them together, and deploys a shared **client API + web** app per customer namespace. It also listens to **Docker Hub webhooks** to roll out new images across all client namespaces automatically.

---

## High-level architecture

* **Panel (this app)** — Node/Express server with a small UI. Runs locally (or anywhere) and talks to:

  * **Hetzner Cloud API** for server lifecycle.
  * **k3s control-planes** over SSH to apply YAML, label/taint nodes, and run `kubectl` operations.
* **k3s** — 1× control-plane VM + N× client VMs (workers). Ingress NGINX installed on the control-plane.
* **Tenancy model** — 1 namespace per client; deployments named `api` and `web`; labeled namespaces: `managed-by=dashboard`.
* **CD path** — Bitbucket builds/pushes images to Docker Hub → Docker Hub webhook → Panel → `kubectl set image` + `rollout status`.

---

## What the panel exposes

* Static UI at `/` to create clusters and clients.
* REST:

  * `GET /api/meta` – Hetzner types/locations/images.
  * `GET /api/servers` – Known VMs (from local metadata).
  * `GET /api/clusters` – Control-planes (id, IP).
  * `GET /api/clients` – Client entries.
  * `POST /api/cluster/create` – Create control-plane (k3s server + ingress install).
  * `POST /api/client/create` – Create worker, join it, label/taint, and deploy per-client API/Web.
  * `POST /api/hook/redeploy?token=…` – Roll out images to all client namespaces.
* WS terminal bridge to servers (simple SSH over websockets).

Auth to the panel uses **Basic Auth** via env (`PANEL_USER`/`PANEL_PASS`).

---

## Expected container images

* **API:** `docker.io/<ns>/client-api:<tag>`
* **Web:** `docker.io/<ns>/client-web:<tag>`

Default for new clients comes from `DEFAULT_API_IMAGE` and `DEFAULT_WEB_IMAGE` (typically `:latest`). Ingress is **path-based**:


## Webhook contract

* **Docker Hub (automated):** When `client-api` or `client-web` is pushed, Docker Hub sends its standard JSON. The panel updates remembered tags and rolls out.

## Environment

Create a `.env` alongside the backend with help of env.example

---

## CI/CD (Bitbucket + Docker Hub)

Bitbucket builds **two images** and pushes tags `latest` and a timestamped SHA tag. Only **Docker Hub** needs to be told to call the panel’s webhook:

* Bitbucket repository variables:

  * `DOCKERHUB_USER` — Docker Hub namespace
  * `DOCKERHUB_TOKEN` — Docker Hub access token (write)

Minimal pipeline (snippet):

```yaml
image: docker:24
options: { docker: true }
pipelines:
  branches:
    main:
      - step:
          name: Build & Push
          services: [docker]
          caches: [docker]
          script:
            - set -euo pipefail
            - : "${DOCKERHUB_USER:?Missing}"
            - : "${DOCKERHUB_TOKEN:?Missing}"
            - echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
            - NS="$DOCKERHUB_USER"
            - SHA_TAG="$(date +%Y%m%d%H%M%S)-$BITBUCKET_COMMIT"
            - docker build -t ${NS}/client-api:latest -t ${NS}/client-api:${SHA_TAG} ./backend
            - docker push ${NS}/client-api:latest
            - docker push ${NS}/client-api:${SHA_TAG}
            - docker build -t ${NS}/client-web:latest -t ${NS}/client-web:${SHA_TAG} ./frontend
            - docker push ${NS}/client-web:latest
            - docker push ${NS}/client-web:${SHA_TAG}
```

On Docker Hub, add a webhook to:

```
https://<your-panel-url>/api/hook/redeploy?token=<WEBHOOK_TOKEN>
```

---

## TL;DR flow

1. IT pushes to `main` → Bitbucket builds `client-api` + `client-web` → pushes to Docker Hub.
2. Docker Hub webhook hits `/api/hook/redeploy?token=…`.
3. Panel SSHes into each control-plane, runs `kubectl set image` + `rollout status` for every `managed-by=dashboard` namespace.
4. Clients get the new containers with zero panel restarts or manual SSH.

That’s the whole loop.
