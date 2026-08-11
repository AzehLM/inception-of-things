#!/bin/bash

# Colors
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Port mappings for K3d loadbalancer:
# 8888 (VM) → 80  : HTTP traffic → Traefik ingress controller → playground app
# 9090 (VM) → 443 : HTTPS traffic → ArgoCD web UI (accessed via kubectl port-forward)
echo -e "${BOLD}${BLUE}Creating K3d cluster${NC}"
k3d cluster create iot-cluster \
    --port "8888:80@loadbalancer" \
    --port "9090:443@loadbalancer" \
    --wait    

echo -e "${BOLD}${BLUE}Creating namespaces${NC}"
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

echo -e "${BOLD}${BLUE}Installing ArgoCD in argocd namespace${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side || true

echo -e "${BOLD}${BLUE}Waiting for ArgoCD server to be ready${NC}"
kubectl wait --for=condition=available \
    --timeout=300s \
    deployment/argocd-server \
    -n argocd

# echo "Exposing ArgoCD server"
# kubectl patch svc argocd-server \
#     -n argocd \
#     -p '{"spec": {"type": "ClusterIP"}}'

echo -e "${BOLD}${BLUE}Applying ArgoCD application config${NC}"
kubectl apply -f confs/argocd-app.yml

echo -e "${BOLD}${BLUE}Waiting for app to be deployed in dev namespace${NC}"
kubectl wait --for=condition=available \
    --timeout=300s \
    deployment/playground \
    -n dev

# echo "Starting ArgoCD port-forward in background"
# sleep 30
# nohup kubectl port-forward svc/argocd-server \
#     -n argocd \
#     9090:443 \
#     --address 0.0.0.0 > /tmp/argocd-portforward.log 2>&1 &

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 --decode)

echo ""
echo "Setup complete."
echo "    Username: admin"
echo "    Password: $ARGOCD_PASSWORD"
