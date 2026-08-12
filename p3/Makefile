.DEFAULT_GOAL	:= all

.PHONY: all
all: install setup

.PHONY: install
install:
	@chmod +x scripts/install.sh
	@./scripts/install.sh

.PHONY: setup
setup:
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh

.PHONY: fclean
fclean:
	@k3d cluster delete iot-cluster

.PHONY: test
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
	@echo "$(BOLD)$(BLUE)Testing app on port 8888${NC}"
	curl -s http://localhost:8888
	@echo ""

BLUE   := \033[0;34m
BOLD   := \033[1m
NC     := \033[0m
