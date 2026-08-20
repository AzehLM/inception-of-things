#!/bin/bash
set -eo pipefail

# Docker
if command -v docker &> /dev/null; then
  echo "[docker] already installed ($(docker --version)), skipping install"
else
  echo "[docker] installing..."
  # -f fail silently, -s silence mode (no progress bar), -S show errors if fails (even in silent mode), -L follow HTTP redirections
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi

if id -nG "$USER" | grep -qw docker; then
  echo "[docker] user '$USER' already in docker group, skipping usermod"
else
  echo "[docker] adding '$USER' to docker group..."
  sudo usermod -aG docker "$USER"
  echo "[docker] you must log out/in (or 'newgrp docker') for the group change to take effect"
fi

# Kubectl
if command -v kubectl &> /dev/null; then
  echo "[kubectl] already installed ($(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion || true)), skipping install"
else
  echo "[kubectl] installing..."
  KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

# K3d
if command -v k3d &> /dev/null; then
  echo "[k3d] already installed ($(k3d version | head -n1)), skipping install"
else
  echo "[k3d] installing..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# jq - used for gitlab setup
if command -v jq &> /dev/null; then
  echo "[jq] already installed, skipping install"
else
  echo "[jq] installing..."
  sudo apt-get update -qq && sudo apt-get install -y jq
fi

echo
echo "All packages installed. Run setup.sh next to create the cluster and deploy Argo CD."
echo
