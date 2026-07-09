DEFAULT_GOAL: all

.PHONY: all
all:
	vagrant up guebersoS ; vagrant up guebersoSW

.PHONY: check
check:
	vagrant ssh guebersoS -c "kubectl get nodes -o wide"

.PHONY: fclean
fclean:
	vagrant destroy -f
