# Colors
BLUE   := \033[0;34m
BOLD   := \033[1m
NC     := \033[0m

.PHONY: all install setup test clean port

all: install setup

install:
	@echo "$(BOLD)$(BLUE)Installing required tools${NC}"
	@bash scripts/install.sh

setup:
	@echo "$(BOLD)$(BLUE)Setting up K3d cluster and ArgoCD${NC}"
	@bash scripts/setup.sh

port:
	@echo "$(BOLD)$(BLUE)Forwarding Port to access ArgoCD on https://localhost:8080 on main machine${NC}"
	kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0

test:
	@echo "$(BOLD)$(BLUE)Checking cluster nodes${NC}"
	kubectl get nodes
	@echo ""
	@echo "$(BOLD)$(BLUE)Checking namespaces${NC}"
	kubectl get ns | grep -E "argocd|dev"
	@echo ""
	@echo "$(BOLD)$(BLUE)Checking ArgoCD pods${NC}"
	kubectl get pods -n argocd
	@echo ""
	@echo "$(BOLD)$(BLUE)Checking app in dev namespace${NC}"
	kubectl get pods -n dev
	@echo ""
	@echo "$(BOLD)$(BLUE)Checking ArgoCD application sync status${NC}"
	kubectl get application -n argocd
	@echo ""
	@echo "$(BOLD)$(BLUE)Checking ingress${NC}"
	kubectl get ingress -n dev
	@echo ""
	@echo "$(BOLD)$(BLUE)Testing app on port 8888${NC}"
	curl -s http://localhost:8888
	@echo "\n"
	@echo "$(BOLD)$(BLUE)Current app version:${NC}"
	kubectl get deployment playground -n dev \
		-o jsonpath='{.spec.template.spec.containers[0].image}'
	@echo ""

clean:
	@echo "Deleting K3d cluster"
	-k3d cluster delete iot-cluster
