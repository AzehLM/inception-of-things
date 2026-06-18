#!/bin/bash
sudo apt-get update && sudo apt-get install -y curl
curl -sfL https://get.k3s.io | sh -s - --node-ip 192.168.56.110 --bind-address 192.168.56.110