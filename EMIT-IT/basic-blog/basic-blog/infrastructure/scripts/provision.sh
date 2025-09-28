
#!/bin/bash
set -e

CLIENT=$1
DOMAIN=$2
EMAIL="admin@example.com" # change to real ACME email

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <client> <domain>"
  exit 1
fi

echo "🚀 Provisioning client: $CLIENT at $DOMAIN"

export HCLOUD_TOKEN=$HCLOUD_TOKEN

# --- 1. Provision with Tofu ---
cd basic-blog/infrastructure/tofu
tofu init -input=false
tofu apply -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# --- 2. Generate inventory ---
tofu output -raw ansible_inventory > ../ansible/inventory.yml

cd ../ansible

# --- 3. Install k3s ---
ansible-playbook -i inventory.yml playbooks/01_k3s.yml

# --- 4. Bootstrap Traefik + cert-manager + namespace ---
ansible-playbook -i inventory.yml playbooks/02_bootstrap.yml \
  --extra-vars "email_lets_encrypt=$EMAIL client_namespace=$CLIENT"

# --- 5. Deploy Helm client stack ---
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client=$CLIENT domain=$DOMAIN"

echo "✅ Client $CLIENT deployed at $DOMAIN"
