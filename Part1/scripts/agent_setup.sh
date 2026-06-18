#!/bin/bash
sudo apt-get update && sudo apt-get install -y curl
TOKEN=$(ssh vagrant@192.168.56.110 sudo cat /var/lib/rancher/k3s/server/node-token)
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN sh -s - --node-ip 192.168.56.111