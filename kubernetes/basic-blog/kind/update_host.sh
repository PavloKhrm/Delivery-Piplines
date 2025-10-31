IP=$1
CLIENT_ID=$2
BASE_DOMAIN=$3

HOSTS_PATH="/etc/hosts"
HOST_ENTRIES="${IP} ${CLIENT_ID}.${BASE_DOMAIN}\n${IP} phpmyadmin.${CLIENT_ID}.${BASE_DOMAIN}\n${IP} mail.${CLIENT_ID}.${BASE_DOMAIN}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with 'sudo ./new-client.sh' to auto-update hosts. Add these lines manually:"
  echo -e "$HOST_ENTRIES"
  exit
fi

grep -q "${CLIENT_ID}.${BASE_DOMAIN}" "$HOSTS_PATH" || echo -e "$HOST_ENTRIES" | sudo tee -a "$HOSTS_PATH"
echo "Hosts file updated."