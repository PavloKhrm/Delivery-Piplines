if [ -z "$1" ]; then
  echo "Error: Please provide a ClientId."
  echo "Usage: ./new-client.sh <client-id>"
  exit 1
fi

# Run the PowerShell script, passing along the client ID.
# 'pwsh' is the command for PowerShell on Mac/Linux.
pwsh ./k8s/new-client.ps1 -ClientId "$1"