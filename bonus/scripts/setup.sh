#!/bin/bash
set -eo pipefail

CLUSTER_NAME="iot-cluster"

# Relauches the script with a good user in case of docker just installed and user not reconnected (same session) - fixes the manual call to newgrp
if ! docker info &> /dev/null; then
  echo "[docker] current shell lacks docker group membership, re-executing via sg docker..."
  exec sg docker -c "$0 $*"
fi

# Cluster K3d
if k3d cluster list | grep -qw "$CLUSTER_NAME"; then
  echo "[k3d] cluster '$CLUSTER_NAME' already exists, skipping creation"
else
  echo "[k3d] creating cluster '$CLUSTER_NAME'..."
  k3d cluster create "$CLUSTER_NAME" -p "8888:30888@loadbalancer"
fi

# Namespace argocd
if kubectl get namespace argocd &> /dev/null; then
  echo "[argocd] namespace 'argocd' already exists, skipping creation"
else
  echo "[argocd] creating namespace 'argocd'..."
  kubectl create namespace argocd
fi

# GitLab Namespace + deployment
if kubectl get namespace gitlab &> /dev/null; then
  echo "[gitlab] namespace 'gitlab' already exists, skipping creation"
else
  echo "[gitlab] creating namespace 'gitlab'..."
  kubectl apply -f confs/manifests/namespace.yml
fi

if kubectl get deployment gitlab -n gitlab &> /dev/null; then
  echo "[gitlab] already deployed, skipping apply"
else
  echo "[gitlab] deploying (pull will run in background)..."
  kubectl apply -f confs/manifests/gitlab/pvc.yml
  kubectl apply -f confs/manifests/gitlab/deployment.yml
  kubectl apply -f confs/manifests/gitlab/service.yml
fi

# Argo CD - should be launched while pulling GitLab image
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
  echo "[argocd] already deployed, skipping apply"
else
  echo "[argocd] deploying..."
  kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "[argocd] waiting for argocd-server to be available..."
kubectl wait --for=condition=available --timeout=240s deployment/argocd-server -n argocd

echo "[gitlab] waiting for gitlab deployment to be available (this can take a while on first boot)..."
kubectl wait --for=condition=available --timeout=1200s deployment/gitlab -n gitlab

# Port-forwarding in background - next script needs it
echo "[expose] starting port-forwards (background)..."
pkill -f "port-forward svc/argocd-server" 2>/dev/null || true
pkill -f "port-forward svc/gitlab" 2>/dev/null || true

nohup kubectl port-forward svc/gitlab -n gitlab 8081:80 &> /tmp/pf-gitlab.log &
nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 &> /tmp/pf-argocd.log &
sleep 2  # giving tunnel some time to be completely setup before using them

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 --decode)

GITLAB_ROOT_PASSWORD=$(kubectl exec -n gitlab deploy/gitlab -- \
    cat /etc/gitlab/initial_root_password 2>/dev/null | grep '^Password:' | awk '{print $2}')

echo
echo "Infrastructure ready."
echo "Argo CD UI  : https://localhost:8080"
echo "GitLab UI   : http://localhost:8081"
echo
echo "Argo CD admin password: $ARGOCD_PASSWORD"
echo "GitLab root password:   $GITLAB_ROOT_PASSWORD"
echo
