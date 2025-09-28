#!/bin/bash
set -e

CLIENT=$1
DOMAIN=$2

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <client> <domain>"
  exit 1
fi

echo "🔄 Updating client: $CLIENT ($DOMAIN)"

cd infrastructure/ansible
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT client_domain=$DOMAIN"

echo "✅ Client $CLIENT updated"
