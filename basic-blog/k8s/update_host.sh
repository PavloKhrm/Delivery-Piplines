#!/bin/bash
set -e

IP="$1"
CLIENT_ID="$2"
BASE_DOMAIN="$3"

ENV_PATH="./k8s/env"
VALUES_PATH="./k8s/charts/client-stack/values.yaml"
HOSTS_PATH="/etc/hosts"

# -------------------------------
# Load environment file (optional)
# -------------------------------
ENV_FILE="${ENV_PATH}/${CLIENT_ID}.env"
[ ! -f "$ENV_FILE" ] && ENV_FILE="${ENV_PATH}/global.env"

if [ -f "$ENV_FILE" ]; then
  echo "Loading environment from $ENV_FILE"
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  BASE_DOMAIN="${BASE_DOMAIN:-$BASE_DOMAIN}"  # keep CLI override
  [ -z "$BASE_DOMAIN" ] && BASE_DOMAIN="$BASE_DOMAIN"
else
  echo "⚠️  No .env found. Falling back to values.yaml"
  BASE_DOMAIN=$(grep -m1 'baseDomain:' "$VALUES_PATH" | cut -d':' -f2 | xargs)
fi

# Require IP
if [ -z "$IP" ]; then
  echo "Usage: sudo ./update_host.sh <IP> <CLIENT_ID> [BASE_DOMAIN]"
  exit 1
fi

# -------------------------------
# Write entries
# -------------------------------
HOST_ENTRIES="${IP} ${CLIENT_ID}.${BASE_DOMAIN}\n${IP} phpmyadmin.${CLIENT_ID}.${BASE_DOMAIN}\n${IP} mail.${CLIENT_ID}.${BASE_DOMAIN}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with 'sudo ./update_host.sh' to auto-update hosts. Add these lines manually:"
  echo -e "$HOST_ENTRIES"
  exit 0
fi

if ! grep -q "${CLIENT_ID}.${BASE_DOMAIN}" "$HOSTS_PATH"; then
  echo -e "$HOST_ENTRIES" | sudo tee -a "$HOSTS_PATH" > /dev/null
  echo "✅ Hosts file updated successfully."
else
  echo "ℹ️  Hosts file already contains these entries."
fi

echo ""
echo "Accessible URLs:"
echo "  http://${CLIENT_ID}.${BASE_DOMAIN}"
echo "  http://phpmyadmin.${CLIENT_ID}.${BASE_DOMAIN}"
echo "  http://mail.${CLIENT_ID}.${BASE_DOMAIN}"
