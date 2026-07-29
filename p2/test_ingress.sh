#!/bin/bash

SERVER_IP="192.168.56.110"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


echo -e "${GREEN}[1/3] Testing: app1.com${NC}"
response=$(curl -s -H "Host: app1.com" http://$SERVER_IP)
if [ $? -eq 0 ] && [ ! -z "$response" ]; then
    echo "$response" | grep -E "Hostname:|IP:|Headers:" || echo "$response"
else
    echo -e "${RED}Error connecting to app1.com${NC}"
fi
echo "--------------------------------------------------"
echo ""

echo -e "${GREEN}[2/3] Testing: app2.com${NC}"
response=$(curl -s -H "Host: app2.com" http://$SERVER_IP)
if [ $? -eq 0 ] && [ ! -z "$response" ]; then
    echo "$response" | grep -E "Hostname:|IP:|Headers:" || echo "$response"
else
    echo -e "${RED}Error connecting to app2.com${NC}"
fi
echo "--------------------------------------------------"
echo ""

echo -e "${GREEN}[3/3] Testing: Default (No Host Header)${NC}"
response=$(curl -s http://$SERVER_IP)
if [ $? -eq 0 ] && [ ! -z "$response" ]; then
    echo "$response" | grep -E "Hostname:|IP:|Headers:" || echo "$response"
else
    echo -e "${RED}Error connecting to default backend${NC}"
fi
echo "=================================================="
