#!/bin/bash

set -e  # exit immediately if a command fails

echo "Installing dependencies"
sudo apt-get update
sudo apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

echo "Installing Docker"
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

echo "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "Installing K3d"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# if I want to interact with argoCD in terminal
# echo "Installing ArgoCD CLI"
# curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
# sudo install -o root -g root -m 0755 argocd /usr/local/bin/argocd
# rm argocd

echo "Verifying installations"
docker --version
kubectl version --client
k3d version

