#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
kind create cluster --config kind-config.yaml
helm repo add cilium https://helm.cilium.io/ && helm repo update
helm install cilium cilium/cilium --version 1.17.6 --namespace kube-system \
  --set image.pullPolicy=IfNotPresent --set ipam.mode=kubernetes \
  --set k8sServiceHost=netlab-control-plane --set k8sServicePort=6443 \
  --set hubble.enabled=true --set hubble.relay.enabled=true --set hubble.ui.enabled=true
kubectl -n kube-system rollout status ds/cilium --timeout=300s
kubectl apply -f manifests/
for d in backend frontend client; do kubectl -n demo rollout status deploy/$d; done
echo "Baseline:"; 
kubectl -n demo exec deploy/frontend -- curl -s -m 5 http://backend
