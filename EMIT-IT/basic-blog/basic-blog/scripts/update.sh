#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infrastructure"
ANSIBLE_DIR="$INFRA_DIR/ansible"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Load infra secrets ---
if [ -f "$INFRA_DIR/.env" ]; then
  export $(grep -v '^#' "$INFRA_DIR/.env" | xargs)
else
  echo -e "${YELLOW}⚠️  No .env file found in ${INFRA_DIR}. Continuing...${NC}"
fi

CLIENT=$1
DOMAIN=$2

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo -e "${RED}❌ Usage: $0 <client> <domain>${NC}"
  echo "Example: ./scripts/update.sh testclient testclient.local"
  exit 1
fi

echo -e "${YELLOW}🔄 Updating Helm deployment for client: ${CLIENT} (${DOMAIN})${NC}"

# --- Validate inventory file ---
if [ ! -f "$ANSIBLE_DIR/inventory.yml" ]; then
  echo -e "${RED}❌ inventory.yml not found. Run provision.sh first.${NC}"
  exit 1
fi

# --- Run Ansible deploy playbook ---
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT client_domain=$DOMAIN"

echo -e "${GREEN}✅ Client ${CLIENT} successfully updated at https://${DOMAIN}${NC}"
