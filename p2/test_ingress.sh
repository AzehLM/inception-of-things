#!/bin/bash

SERVER_IP="192.168.56.110"

echo "[1/3] REquest app1.com :"
curl -s -H "Host: app1.com" http://$SERVER_IP | grep -i "Hostname" || echo "Erreur de connexion"
echo ""

echo "[2/3] Request sur app2.com :"
curl -s -H "Host: app2.com" http://$SERVER_IP | grep -i "Hostname" || echo "Erreur de connexion"
echo ""

echo "[3/3] Request no Host header :"
curl -s http://$SERVER_IP | grep -i "Hostname"
echo ""
