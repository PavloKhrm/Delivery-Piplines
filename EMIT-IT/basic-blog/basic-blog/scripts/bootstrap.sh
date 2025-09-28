#!/bin/bash
set -e

echo "🚀 Bootstrapping local environment..."

# Install dependencies if not present
if ! command -v tofu &> /dev/null; then
  echo "Installing OpenTofu..."
  curl -sSfL https://get.opentofu.org/install.sh | sudo bash
fi

if ! command -v ansible &> /dev/null; then
  echo "Installing Ansible..."
  sudo apt-get update -y && sudo apt-get install -y ansible
fi

if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
fi

echo "✅ Local environment ready!"
