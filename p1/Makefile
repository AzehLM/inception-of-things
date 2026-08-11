# Makefile for K3s cluster setup with Vagrant + Ansible
# Usage: make <target>

PROVIDER = libvirt

.PHONY: all up provision test clean help

# Default target: full setup from scratch
all: up provision test

# Bring up VMs one by one to avoid DHCP contention on nested virtualization
up:
	@echo "==> Starting server node..."
	vagrant up lbuissonS --provider=$(PROVIDER)
	@echo "==> Starting agent node..."
	vagrant up lbuissonSW --provider=$(PROVIDER)

# Run Ansible playbooks in order: server first (installs K3s + configures SSH),
# then agent (joins the cluster using the token saved by the server playbook)
provision:
	@echo "==> Provisioning server (K3s master + SSH keys)..."
	ansible-playbook -i inventory.ini playbooks/server.yml
	@echo "==> Provisioning agent (K3s worker)..."
	ansible-playbook -i inventory.ini playbooks/agent.yml

# Verify the cluster is healthy: both nodes should appear as Ready
test:
	@echo "==> Checking cluster nodes..."
	ansible -i inventory.ini server -m shell -a "sudo kubectl get nodes"
	@echo "==> Testing passwordless SSH agent -> server..."
	vagrant ssh lbuissonSW -- ssh -o StrictHostKeyChecking=no vagrant@192.168.56.110 echo "Agent -> Server OK"
	@echo "==> Testing passwordless SSH server -> agent..."
	vagrant ssh lbuissonS -- ssh -o StrictHostKeyChecking=no vagrant@192.168.56.111 echo "Server -> Agent OK"

# Destroy everything cleanly
clean:
	@echo "==> Destroying VMs..."
	-vagrant destroy -f
	@echo "==> Cleaning up libvirt leftovers..."
	-sudo virsh destroy p1_lbuissonS 2>/dev/null
	-sudo virsh destroy p1_lbuissonSW 2>/dev/null
	-sudo virsh undefine p1_lbuissonS --remove-all-storage 2>/dev/null
	-sudo virsh undefine p1_lbuissonSW --remove-all-storage 2>/dev/null
	-sudo virsh net-destroy k3s_network 2>/dev/null
	-sudo virsh net-undefine k3s_network 2>/dev/null
	-sudo virsh net-destroy vagrant-libvirt 2>/dev/null
	-sudo virsh net-undefine vagrant-libvirt 2>/dev/null
	-rm -rf .vagrant/
	@echo "==> Done."

# Show available targets
help:
	@echo "Available targets:"
	@echo "  make all        - Full setup: up + provision + test"
	@echo "  make up         - Start VMs one by one"
	@echo "  make provision  - Run Ansible playbooks"
	@echo "  make test       - Verify cluster and SSH"
	@echo "  make clean      - Destroy everything"