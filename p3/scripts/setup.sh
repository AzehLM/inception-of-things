#!/bin/bash
set -eo pipefail

CLUSTER_NAME="iot-cluster"
APP_MANIFEST="./confs/manifests/application.yml"

# Cluster K3d
if k3d cluster list | grep -qw "$CLUSTER_NAME"; then
  echo "[k3d] cluster '$CLUSTER_NAME' already exists, skipping creation"
else
  echo "[k3d] creating cluster '$CLUSTER_NAME'..."
  k3d cluster create "$CLUSTER_NAME" -p "8888:30888@loadbalancer" # -p "8888:30888@loadbalancer" maps host port 8888 to port 30888 on the k3d-managed serverlb (server load balancer)
fi

# Namespace argocd
if kubectl get namespace argocd &> /dev/null; then
  echo "[argocd] namespace 'argocd' already exists, skipping creation"
else
  echo "[argocd] creating namespace 'argocd'..."
  kubectl create namespace argocd # mandatory namespace to create in the setup, the dev one will be created via manifests
fi

# Argo CD
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
  echo "[argocd] already deployed, skipping apply"
else
  echo "[argocd] deploying..."
  kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "[argocd] waiting for argocd-server to be available..."
kubectl wait --for=condition=available --timeout=240s deployment/argocd-server -n argocd

# Application (bootstrap)
# we are using the server API kubectl.kubernetes.io/last-applied-configuration value to unsure we have to apply or not the manifests
echo "[argocd] applying application manifest..."
kubectl apply -f "$APP_MANIFEST"

echo "[argocd] waiting for Argo CD to sync and create the wil-app service in the 'dev' namespace..."
until kubectl get svc wil-app -n dev &> /dev/null; do
  sleep 2
done
kubectl wait --for=condition=available --timeout=120s deployment/wil-app -n dev

# Port-forwarding in background
echo "[expose] starting port-forwards (background)..."
pkill -f "port-forward svc/argocd-server" 2>/dev/null || true
pkill -f "port-forward svc/wil-app" 2>/dev/null || true

nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 &> /tmp/pf-argocd.log &

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 --decode)

echo
echo "All done."
echo "Argo CD UI  : https://localhost:8080"
echo "wil-app     : http://localhost:8888"
echo
echo "Admin password:"
echo "$ARGOCD_PASSWORD"
