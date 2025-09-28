#!/bin/bash
set -e

CLIENT=$1

if [ -z "$CLIENT" ]; then
  echo "Usage: $0 <client>"
  exit 1
fi

echo "Destroying client: $CLIENT"

# --- Remove Helm release + namespace ---
cd infrastructure/ansible
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT" --tags "destroy"

# --- Destroy infra ---
cd ../tofu
tofu destroy -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

echo "✅ Client $CLIENT removed"
