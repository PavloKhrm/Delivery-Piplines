if [ -z "$1" ]; then
  echo "Error: Please provide a ClientId."
  echo "Usage: ./new-client.sh <client-id>"
  exit 1
fi

pwsh ./kind/new-client.ps1 -ClientId "$1"