#!/bin/bash
set -e

# --- Load infra secrets ---
if [ -f "../infrastructure/.env" ]; then
  export $(grep -v '^#' ../infrastructure/.env | xargs)
fi

KUBECONFIG="../infrastructure/ansible/kubeconfig_cluster.yaml"

echo "Cluster status:"
kubectl --kubeconfig $KUBECONFIG get nodes -o wide
echo ""

echo "Client workloads:"
kubectl --kubeconfig $KUBECONFIG get pods -A
echo ""

echo "Ingress:"
kubectl --kubeconfig $KUBECONFIG get ingress -A
echo ""

echo "Certificates:"
kubectl --kubeconfig $KUBECONFIG get certificates -A || true
