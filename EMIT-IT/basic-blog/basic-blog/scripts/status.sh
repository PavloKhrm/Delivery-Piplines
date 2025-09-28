#!/bin/bash
set -e

echo "Cluster status:"
kubectl --kubeconfig infrastructure/ansible/kubeconfig_cluster.yaml get nodes -o wide
echo ""

echo "Client workloads:"
kubectl --kubeconfig infrastructure/ansible/kubeconfig_cluster.yaml get pods -A
echo ""

echo "Ingress:"
kubectl --kubeconfig infrastructure/ansible/kubeconfig_cluster.yaml get ingress -A
echo ""

echo "Certificates:"
kubectl --kubeconfig infrastructure/ansible/kubeconfig_cluster.yaml get certificates -A || true
