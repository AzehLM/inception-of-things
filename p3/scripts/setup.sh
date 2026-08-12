#!/bin/bash
set -euo pipefail

CLUSTER_NAME="iot-cluster"
APP_MANIFEST="./confs/manifests/application.yml"

if k3d cluster list | grep -qw "$CLUSTER_NAME"; then
  echo "[k3d] cluster '$CLUSTER_NAME' already exists, skipping creation"
else
  echo "[k3d] creating cluster '$CLUSTER_NAME'..."
  k3d cluster create "$CLUSTER_NAME"
fi

if kubectl get namespace argocd &> /dev/null; then
  echo "[argocd] namespace 'argocd' already exists, skipping creation"
else
  echo "[argocd] creating namespace 'argocd'..."
  kubectl create namespace argocd
fi

if kubectl get deployment argocd-server -n argocd &> /dev/null; then
  echo "[argocd] already deployed, skipping apply"
else
  echo "[argocd] deploying..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "[argocd] waiting for argocd-server to be available..."
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

if kubectl get application p3 -n argocd &> /dev/null; then
  echo "[argocd] application 'p3' already exists, skipping apply"
else
  echo "[argocd] applying application manifest..."
  kubectl apply -f "$APP_MANIFEST"
fi

echo "[argocd] waiting for Argo CD to sync and create the wil-app service in 'dev'..."
until kubectl get svc wil-app -n dev &> /dev/null; do
  sleep 3
done
kubectl wait --for=condition=available --timeout=120s deployment/wil-app -n dev

echo "[expose] starting port-forwards (background)..."
pkill -f "port-forward svc/argocd-server" 2>/dev/null || true
pkill -f "port-forward svc/wil-app" 2>/dev/null || true

nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 &> /tmp/pf-argocd.log &
nohup kubectl port-forward svc/wil-app -n dev 8888:8888 &> /tmp/pf-wilapp.log &

echo
echo "All done."
echo "Argo CD UI  : https://localhost:8080  (login: admin)"
echo "wil-app     : http://localhost:8888"
echo
echo "Admin password:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
