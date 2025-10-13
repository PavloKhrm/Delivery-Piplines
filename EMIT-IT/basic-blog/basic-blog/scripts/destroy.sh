#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infrastructure"
ANSIBLE_DIR="$INFRA_DIR/ansible"
TOFU_DIR="$INFRA_DIR/tofu"

# --- Colors for visibility ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Load infra secrets ---
if [ -f "$INFRA_DIR/.env" ]; then
  export $(grep -v '^#' "$INFRA_DIR/.env" | xargs)
fi

CLIENT=$1
if [ -z "$CLIENT" ]; then
  echo -e "${RED}❌ Usage: $0 <client>${NC}"
  exit 1
fi

echo -e "${YELLOW}⚠️  You are about to destroy client environment: ${CLIENT}${NC}"
read -p "Type '${CLIENT}' to confirm: " CONFIRM
if [ "$CONFIRM" != "$CLIENT" ]; then
  echo -e "${RED}Aborted.${NC}"
  exit 1
fi

# --- Check for required env vars ---
if [ -z "$HCLOUD_TOKEN" ]; then
  echo -e "${RED}❌ HCLOUD_TOKEN not set. Export or add it to infrastructure/.env${NC}"
  exit 1
fi

if [ -z "$SSH_KEY_PATH" ]; then
  echo -e "${RED}❌ SSH_KEY_PATH not set. Add it to infrastructure/.env${NC}"
  exit 1
fi

echo -e "${YELLOW}🧹 Cleaning Helm release and namespace for ${CLIENT}...${NC}"
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT" --tags "destroy"

# --- Destroy infra ---
cd "$TOFU_DIR"
echo -e "${YELLOW}🔥 Destroying Hetzner resources for ${CLIENT}...${NC}"

if ! tofu workspace select "$CLIENT" &>/dev/null; then
  tofu workspace new "$CLIENT"
  tofu workspace select "$CLIENT"
fi

tofu init -input=false
tofu destroy -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat $SSH_KEY_PATH)"

# --- Cleanup local remnants ---
cd "$INFRA_DIR"
rm -f ansible/inventory.yml 2>/dev/null || true
rm -f ansible/kubeconfig_* 2>/dev/null || true

echo -e "${GREEN}✅ Client ${CLIENT} successfully destroyed and cleaned up.${NC}"
