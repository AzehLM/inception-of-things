#!/bin/bash
set -e

# Docker - Can cause issues if already installed
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER
rm get-docker.sh

# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Creates the K3d cluster
k3d cluster create iot-cluster

# Argo CD - directly applying a the k8s in the cluster created before
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
