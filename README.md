# EMIT-IT Full Deployment Prototype
Delivery-Pipelines • Hetzner Cloud • OpenTofu • Ansible • K3s • Helm

This README explains **what** to do, **why** you do it, **what to expect**, and **how to verify** each step. Every command is in its own fenced block. This prototype was stopped but in case you want to test this, I have created a readme for you to follow. Most important step is up untill Step 5. The other steps is to confirm if needed, bootstrap and provision script should download most of the things you need you might need to download KIND in wsl. It is not fully ready as this prototype was left off due to project scope so if something is not fully working such as SSL, DNS and some pods might not be fully running. But it does spawn VPS in hetzner and creates cluster and a isolated namespace all in one script, make sure you have a .env like in step 5 and step 4 if you dont have ssh in wsl.  

---

## 0) What you get
- One K3s cluster on Hetzner.
- Isolated client namespaces (e.g., `testclient`, `aron`, `mahmoud`).
- Per‑client stack via Helm: MySQL, Redis, OpenSearch, phpMyAdmin, Mailcrab, Backend, Frontend.
- Commands to provision, deploy, verify, and tear down.

---

## 1) Requirements and assumptions
Why: These are the minimum to run the pipeline.

- OS: **WSL2** (Ubuntu) or **Linux**.
- Shell: Bash.
- Accounts: Hetzner Cloud account with API token.
- Network: Internet access for installing tools and pulling images.
- Access: A working SSH public key.

Verify you are in bash:
```bash
echo "$SHELL"
```

---

## 2) Repo layout (assumed)
Why: Paths in commands rely on this layout. Adjust if your repo differs.

```
<repo-root>/
  scripts/
    bootstrap.sh
  basic-blog/
    charts/client-stack/
    values/
      values.testclient.yaml
    infrastructure/
      .env  (created later)
      tofu/ (OpenTofu files)
  inventory.ini
  playbooks/
    setup-cluster.yml
```

---

## 3) Bootstrap local environment
Why: Installs OpenTofu, Ansible, Helm, and kubectl. Idempotent.

Change to scripts:
```bash
cd scripts
```

Run the bootstrap:
```bash
sudo ./bootstrap.sh
```

Verify tools:
```bash
tofu -version
```
```bash
ansible --version
```
```bash
helm version
```
```bash
kubectl version --client
```

Expected: Each command prints a version. If a tool is missing, the script installs it.

---

## 4) SSH key
Why: Hetzner and Ansible use your SSH key.

Check if a public key exists:
```bash
ls ~/.ssh/id_rsa.pub
```

Create one if missing:
```bash
ssh-keygen -t rsa -b 4096 -C "you@example.com"
```

Upload `~/.ssh/id_rsa.pub` to Hetzner Cloud → **SSH Keys**.

---

## 5) Hetzner API token and `.env`
Why: OpenTofu uses the token. Playbooks and scripts read the `.env`.

Create `.env` under `basic-blog/infrastructure/`:
```bash
mkdir -p basic-blog/infrastructure
cat > basic-blog/infrastructure/.env <<'EOF'
HCLOUD_TOKEN=your-hetzner-api-token
SSH_KEY_PATH=~/.ssh/id_rsa.pub
EOF
```

Validate:
```bash
grep -E 'HCLOUD_TOKEN|SSH_KEY_PATH' basic-blog/infrastructure/.env
```

Expected: Two lines with your token placeholder and key path. Replace the token with a real value before provisioning.

---

## 6) Provision infrastructure (OpenTofu)
Why: Creates Hetzner servers, network, and access. Safe to re-apply.

Move to tofu directory:
```bash
cd basic-blog/infrastructure/tofu
```

Initialize providers:
```bash
tofu init
```

Apply plan (non‑interactive):
```bash
tofu apply -auto-approve
```

Return to repo root:
```bash
cd ../../../..
```

Expected: OpenTofu shows resources created. If it fails on credentials, re-check the `.env` token and your Hetzner account limits.

Destroy later if needed:
```bash
cd basic-blog/infrastructure/tofu
tofu destroy -auto-approve
cd ../../../..
```

---

## 7) Configure cluster (Ansible + K3s)
Why: Turns fresh hosts into a working K3s cluster. Installs Traefik and cert-manager if defined in the playbook.

Run from repo root:
```bash
ansible-playbook -i inventory.ini playbooks/setup-cluster.yml
```

Expected: Tasks become green or changed. No fatal errors. Re‑running is allowed and safe (idempotent).

---

## 8) Deploy a client stack (Helm)
Why: Each client gets an isolated namespace and a full app stack.

Create namespace:
```bash
kubectl create namespace <clientname>
```

Change to app root:
```bash
cd basic-blog
```

Deploy or upgrade:
```bash
helm upgrade --install <clientname> ./charts/client-stack   --namespace <clientname>   --values values/values.<clientname>.yaml   --atomic --wait --timeout 10m
```

Example namespace:
```bash
kubectl create namespace testclient
```

Example deploy:
```bash
helm upgrade --install testclient ./charts/client-stack   --namespace testclient   --values values/values.testclient.yaml   --atomic --wait --timeout 10m
```

Return to repo root:
```bash
cd ..
```

Expected: Helm finishes with `STATUS: deployed`. If it times out, increase `--timeout` and check cluster events.

---

## 9) Verify deployments
Why: Confirm the release and pods are healthy.

List all Helm releases:
```bash
helm list -A
```

List pods in namespace:
```bash
kubectl get pods -n <clientname>
```

Show a pod’s logs:
```bash
kubectl logs <pod-name> -n <clientname>
```

Describe a pod:
```bash
kubectl describe pod <pod-name> -n <clientname>
```

Describe a node:
```bash
kubectl describe node <node-name>
```

Expected: Pods should be `Running` or `Completed`. Investigate `CrashLoopBackOff` via logs.

---

## 10) Troubleshooting quick wins
Why: Short actions to unblock common failures.

Increase Helm timeout and force atomic wait:
```bash
helm upgrade --install <release> <chart> --namespace <ns> --timeout 10m --atomic --wait
```

See latest cluster events:
```bash
kubectl get events -A --sort-by=.lastTimestamp
```

See previous crash logs of a container:
```bash
kubectl logs <pod> -n <ns> --previous
```

Create a missing namespace:
```bash
kubectl create namespace <client>
```

Check node capacity if pods are Pending:
```bash
kubectl describe node <node>
```

Read an app .env inside a container (path may vary):
```bash
kubectl exec -it <pod> -n <ns> -- cat /app/.env
```

DNS/SSL note: Real domains and a proper ClusterIssuer are required. If not available, defer SSL.

---

## 11) Cleanup
Why: Reclaim resources or reset a client environment.

Uninstall a client release:
```bash
helm uninstall <client> -n <client>
```

Delete a namespace:
```bash
kubectl delete namespace <client>
```

Destroy all infrastructure (irreversible):
```bash
cd basic-blog/infrastructure/tofu
tofu destroy -auto-approve
cd ../../../..
```

---

## 12) Patterns and tips
- One client = one namespace. Isolation and simpler quotas.
- Store per‑client settings in `values/values.<client>.yaml`.
- Playbooks and Helm charts are safe to re-run.
- Prefer `--atomic --wait` in Helm for consistent rollbacks.
- Keep `.env` out of version control.

