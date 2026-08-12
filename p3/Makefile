.DEFAULT_GOAL	:= all

all: install | setup


install:
	@chmod +x ./scripts/install.sh
	@./scripts/install.sh

setup:
	@chmod +x ./scripts/setup.sh
	@./scripts/setup.sh

fclean:
	@k3d cluster delete iot-cluster
