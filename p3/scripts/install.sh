#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'


if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW} Installing Docker${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh

    sudo usermod -aG docker $USER
    echo -e "${GREEN} Docker installed successfully!${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing kubectl${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo -e "${GREEN}kubectl installed successfully!${NC}"
else
    echo -e "${GREEN}kubectl is already installed.${NC}"
fi

if ! command -v k3d &> /dev/null; then
    echo -e "${YELLOW}Installing k3d...${NC}"
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.6.0 bash
    echo -e "${GREEN}k3d installed successfully!${NC}"
else
    echo -e "${GREEN}k3d is already installed.${NC}"
fi
