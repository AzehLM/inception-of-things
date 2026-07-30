#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


response=$(curl -s http://localhost:8888/)
if [ $? -eq 0 ] && [ ! -z "$response" ]; then
    echo -e "${GREEN} Connected to application!${NC}"
    echo "Response: $response"
else
    echo -e "${RED} Failed to connect to http://localhost:8888/${NC}"
fi
