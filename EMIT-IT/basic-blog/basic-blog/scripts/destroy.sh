#!/bin/bash
set -e

# --- Load infra secrets ---
if [ -f "../infrastructure/.env" ]; then
  export $(grep -v '^#' ../infrastructure/.env | xargs)
fi

CLIENT=$1

if [ -z "$CLIENT" ]; then
  echo "Usage: $0 <client>"
  exit 1
fi

echo "Destroying client: $CLIENT"

# --- Remove Helm release + namespace ---
cd ../infrastructure/ansible
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT" --tags "destroy"

# --- Destroy infra ---
cd ../infrastructure/tofu
# Switch to a workspace for this client (or create it if it doesn't exist)
if ! tofu workspace select "$CLIENT" &>/dev/null; then
  tofu workspace new "$CLIENT"
  tofu workspace select "$CLIENT"
fi
tofu init -input=false
tofu destroy -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat $SSH_KEY_PATH)"

echo "✅ Client $CLIENT removed"
