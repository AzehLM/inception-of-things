#!/bin/bash


set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo -e "${YELLOW}[1/4] Creating K3d cluster 'dev-cluster'...${NC}"

if k3d cluster list | grep -q "dev-cluster"; then
    echo -e "${GREEN}[OK] Cluster 'dev-cluster' already exists. Skipping creation.${NC}"
else
    k3d cluster create dev-cluster \
        --port "8888:80@loadbalancer" \
        --api-port 6443 \
        --agents 1 \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@server:*" \
        --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@agent:*" \
        --wait
    echo -e "${GREEN}[OK] Cluster 'dev-cluster' created successfully.${NC}"
fi

kubectl config use-context k3d-dev-cluster


echo -e "${YELLOW}[2/4] Installing Argo CD...${NC}"

kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${GREEN}[OK] Argo CD manifests applied successfully.${NC}"

echo -e "${YELLOW}[3/4] Waiting for Argo CD server to be ready...${NC}"

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo -e "${GREEN}[OK] Argo CD server is ready.${NC}"

echo -e "${YELLOW}[4/4] Deploying application via Argo CD...${NC}"

kubectl apply -f "$PROJECT_DIR/confs/application.yaml"

echo -e "${GREEN}[OK] Application manifest applied successfully.${NC}"


echo ""
echo -e "${GREEN}  Setup completed successfully!${NC}"
echo -e "  Application URL: ${CYAN}http://localhost:8888/${NC}"
echo -e "  Check Pods status: ${CYAN}kubectl get pods -n dev${NC}"
