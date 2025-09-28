#!/bin/bash
set -e

CLIENT=$1
DOMAIN=$2
EMAIL="admin@example.com" # replace with your ACME email

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <client> <domain>"
  exit 1
fi

echo "Provisioning client: $CLIENT at $DOMAIN"

# --- Check Hetzner token ---
if [ -z "$HCLOUD_TOKEN" ]; then
  echo "HCLOUD_TOKEN not set. Run: export HCLOUD_TOKEN=your-token"
  exit 1
fi

# --- Terraform (Tofu) ---
cd infrastructure/tofu
tofu init -input=false
tofu apply -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# --- Export inventory.yml ---
tofu output -raw ansible_inventory > ../ansible/inventory.yml
cd ../ansible

# --- Install k3s cluster (multi-node) ---
ansible-playbook -i inventory.yml playbooks/01_k3s.yml

# --- Bootstrap cluster services ---
ansible-playbook -i inventory.yml playbooks/02_bootstrap.yml \
  --extra-vars "email_lets_encrypt=$EMAIL client_namespace=$CLIENT"

# --- Deploy client stack ---
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT client_domain=$DOMAIN"

echo "✅ Client $CLIENT deployed at https://$DOMAIN"
