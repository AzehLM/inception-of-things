#!/bin/bash

echo "Creating K3d cluster"
k3d cluster create iot-cluster \
    --port "8888:80@loadbalancer" \
    --port "9090:443@loadbalancer" \
    --wait    

echo "Creating namespaces"
kubectl create namespace argocd
kubectl create namespace dev

echo "Installing ArgoCD in argocd namespace"
echo "Installing ArgoCD in argocd namespace"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side || true

echo "Waiting for ArgoCD server to be ready"
kubectl wait --for=condition=available \
    --timeout=300s \
    deployment/argocd-server \
    -n argocd

echo "Exposing ArgoCD server"
kubectl patch svc argocd-server \
    -n argocd \
    -p '{"spec": {"type": "ClusterIP"}}'

echo "Applying ArgoCD application config"
kubectl apply -f confs/argocd-app.yml

echo "Waiting for app to be deployed in dev namespace"
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

echo "Cluster status:"
kubectl get nodes
echo ""
echo "ArgoCD pods:"
kubectl get pods -n argocd
echo ""
echo "App in dev namespace:"
kubectl get pods -n dev
echo ""
echo "Current app version:"
kubectl get deployment playground -n dev \
    -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
echo ""
echo "Setup complete."
echo "    ArgoCD web interface: https://IP:9090"
echo "    Username: admin"
echo "    Password: $ARGOCD_PASSWORD"
echo ""
echo "    To change app version: edit manifests/deployment.yml in your GitHub repo"
echo "    Change image tag from v1 to v2 and push — ArgoCD will auto-sync"