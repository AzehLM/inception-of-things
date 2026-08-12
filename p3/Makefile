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
