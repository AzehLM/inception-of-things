#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"


cd "$PROJECT_DIR"

if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    REMOTE_URL=$(git config --get remote.origin.url)
    if [ ! -z "$REMOTE_URL" ]; then
        if [[ "$REMOTE_URL" =~ ^git@github\.com:(.+)\.git$ ]]; then
            HTTPS_URL="https://github.com/${BASH_REMATCH[1]}.git"
        elif [[ "$REMOTE_URL" =~ ^https://github\.com/ ]]; then
            HTTPS_URL="$REMOTE_URL"
        else
            HTTPS_URL="$REMOTE_URL"
        fi
        HTTPS_URL=$(echo "$HTTPS_URL" | sed -E 's|https://[^@]+@github.com|https://github.com|g')

        echo -e "${YELLOW}Detected Git Remote URL: $HTTPS_URL${NC}"
        echo -e "${YELLOW}Updating repoURL in application.yaml...${NC}"

        sed -i -E "s|repoURL: '.*'|repoURL: '$HTTPS_URL'|g" "$PROJECT_DIR/confs/application.yaml"
    fi
fi

echo -e "${YELLOW}[1/4] Creating K3d cluster 'dev-cluster'...${NC}"
if k3d cluster list | grep -q "dev-cluster"; then
    echo -e "${GREEN}[✓] Cluster 'dev-cluster' already exists. Skipping creation.${NC}"
else
    k3d cluster create dev-cluster --port "8888:80@loadbalancer" --api-port 6443 --agents 1 --wait
    if [ $? -ne 0 ]; then
        echo -e "${RED} Failed to create K3d cluster.${NC}"
        exit 1
    fi
    echo -e "${GREEN} K3d cluster 'dev-cluster' created successfully!${NC}"
fi

kubectl config use-context k3d-dev-cluster

echo -e "${YELLOW}[2/4] Deploying Argo CD${NC}"
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to apply Argo CD manifests.${NC}"
    exit 1
fi
echo -e "${GREEN}Argo CD manifests applied.${NC}"

echo -e "${YELLOW}[3/4] Waiting for Argo CD components to be ready${NC}"
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s
if [ $? -ne 0 ]; then
    echo -e "${RED}Argo CD server failed to become ready in time.${NC}"
    exit 1
fi
echo -e "${GREEN}Argo CD server is running!${NC}"

echo -e "${YELLOW}[4/4] Deploying the application via Argo CD${NC}"
kubectl apply -f "$PROJECT_DIR/confs/application.yaml"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to apply the Argo CD Application manifest.${NC}"
    exit 1
fi
echo -e "${GREEN}Argo CD Application applied successfully!${NC}"

echo ""
echo "=================================================="
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "You can access the application at: ${CYAN}http://localhost:8888/${NC}"
echo -e "Check the sync status in Argo CD UI or run:"
echo -e "  ${CYAN}kubectl get pods -n dev${NC}"
echo "=================================================="
