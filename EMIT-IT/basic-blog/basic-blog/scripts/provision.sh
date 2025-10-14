#!/bin/bash
set -e

# ───────────────────────────────────────────────
# PATH SETUP
# ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infrastructure"
ANSIBLE_DIR="$INFRA_DIR/ansible"
TOFU_DIR="$INFRA_DIR/tofu"

# ───────────────────────────────────────────────
# COLORS
# ───────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ───────────────────────────────────────────────
# LOAD ENVIRONMENT VARIABLES
# ───────────────────────────────────────────────
if [ -f "$INFRA_DIR/.env" ]; then
  set -a
  . "$INFRA_DIR/.env"
  set +a
else
  echo -e "${RED}❌ Missing .env file in $INFRA_DIR${NC}"
  exit 1
fi

CLIENT=$1
DOMAIN=$2

if [ -z "$CLIENT" ] || [ -z "$DOMAIN" ]; then
  echo -e "${RED}❌ Usage: $0 <client> <domain>${NC}"
  exit 1
fi

if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
  echo -e "${RED}❌ Invalid domain format: $DOMAIN${NC}"
  exit 1
fi

echo -e "${GREEN}🚀 Provisioning client: ${CLIENT} (${DOMAIN})${NC}"

# ───────────────────────────────────────────────
# CHECK TOKENS AND KEYS
# ───────────────────────────────────────────────
if [ -z "$HCLOUD_TOKEN" ]; then
  echo -e "${RED}❌ HCLOUD_TOKEN not set. Add it to ${INFRA_DIR}/.env or export manually.${NC}"
  exit 1
fi

if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
  echo -e "${RED}❌ SSH key not found or not set. Check SSH_KEY_PATH in .env.${NC}"
  exit 1
fi

echo -e "${YELLOW}🔑 Using SSH key from: $SSH_KEY_PATH${NC}"

# ───────────────────────────────────────────────
# OPEN TOFU APPLY
# ───────────────────────────────────────────────
cd "$TOFU_DIR"
echo -e "${YELLOW}📦 Running OpenTofu apply for ${CLIENT}...${NC}"

if ! tofu workspace select "$CLIENT" &>/dev/null; then
  tofu workspace new "$CLIENT"
  tofu workspace select "$CLIENT"
fi

tofu init -input=false
tofu apply -auto-approve \
  -var="client=$CLIENT" \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat "$SSH_KEY_PATH")"

# ───────────────────────────────────────────────
# GENERATE INVENTORY
# ───────────────────────────────────────────────
echo -e "${YELLOW}🧾 Generating Ansible inventory...${NC}"
tofu output -raw ansible_inventory > "$ANSIBLE_DIR/inventory.yml"

if [ ! -s "$ANSIBLE_DIR/inventory.yml" ]; then
  echo -e "${RED}❌ Failed to generate inventory.yml${NC}"
  exit 1
fi

# ───────────────────────────────────────────────
# VALIDATE SSH CONNECTIVITY
# ───────────────────────────────────────────────
cd "$ANSIBLE_DIR"
echo -e "${YELLOW}🔑 Testing Ansible connectivity...${NC}"

if ! ansible all -i inventory.yml -m ping; then
  echo -e "${RED}❌ SSH connectivity failed. Check firewall or SSH key.${NC}"
  exit 1
fi

# ───────────────────────────────────────────────
# INSTALL K3S
# ───────────────────────────────────────────────
echo -e "${YELLOW}🐳 Installing K3s cluster...${NC}"
ansible-playbook -i inventory.yml playbooks/01_k3s.yml

# ───────────────────────────────────────────────
# BOOTSTRAP CLUSTER
# ───────────────────────────────────────────────
echo -e "${YELLOW}⚙️  Bootstrapping cluster services...${NC}"
ansible-playbook -i inventory.yml playbooks/02_bootstrap.yml \
  --extra-vars "email_lets_encrypt=$EMAIL client_namespace=$CLIENT"

# ───────────────────────────────────────────────
# DEPLOY CLIENT STACK
# ───────────────────────────────────────────────
echo -e "${YELLOW}🚀 Deploying Helm client stack...${NC}"
ansible-playbook -i inventory.yml playbooks/03_deploy_client.yml \
  --extra-vars "client_namespace=$CLIENT client_domain=$DOMAIN"

# ───────────────────────────────────────────────
# DONE
# ───────────────────────────────────────────────
echo -e "${GREEN}✅ Client ${CLIENT} successfully deployed at https://${DOMAIN}${NC}"
