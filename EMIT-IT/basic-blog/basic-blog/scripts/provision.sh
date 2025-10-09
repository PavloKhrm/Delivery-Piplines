#!/bin/bash
set -e

# --- Load infra secrets ---
if [ -f "../infrastructure/.env" ]; then
  set -a
  . ../infrastructure/.env
  set +a
fi

CLIENT=$1
DOMAIN=$2

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <client> <domain>"
  exit 1
fi

echo "Provisioning client: $CLIENT at $DOMAIN"

# --- Check Hetzner token ---
if [ -z "$HCLOUD_TOKEN" ]; then
  echo "HCLOUD_TOKEN not set. Add it to infrastructure/.env or export manually"
  exit 1
fi

# --- Check SSH key path ---
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "SSH key not found at $SSH_KEY_PATH"
  exit 1
fi

# --- Terraform (Tofu) ---
cd ../infrastructure/tofu
# Switch to a workspace for this client (or create it if it doesn't exist)
if ! tofu workspace select "$CLIENT" &>/dev/null; then
  tofu workspace new "$CLIENT"
  tofu workspace select "$CLIENT"
fi
tofu init -input=false
tofu apply -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat $SSH_KEY_PATH)"

# --- Always refresh Ansible inventory ---
echo "Generating fresh Ansible inventory..."
tofu output -raw ansible_inventory > ../ansible/inventory.yml

# --- Verify SSH before playbooks ---
cd ../ansible
echo "🔑 Testing SSH connectivity..."
ansible all -i inventory.yml -m ping || {
  echo "SSH failed! Check your SSH key / firewall."
  exit 1
}

# --- Install k3s cluster (multi-node) ---
ansible-playbook -i inventory.yml playbooks/01_k3s.yml

# --- Bootstrap cluster services ---
ansible-playbook -i inventory.yml playbooks/02_bootstrap.yml \
  --extra-vars "email_lets_encrypt=$EMAIL client_namespace=$CLIENT"

# --- Deploy client stack ---
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT client_domain=$DOMAIN"

echo "✅ Client $CLIENT deployed at https://$DOMAIN"
