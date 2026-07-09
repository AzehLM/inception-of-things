# Inception of Things

This project is an introduction to system administration, network clustering, and container orchestration using **Kubernetes**. It covers setting up lightweight Kubernetes environments with **K3s** and **K3d**, and automating deployments using **Vagrant** and **Argo CD**.

---

## Definition

* **Kubernetes** (K8s) : an open-source **container orchestration platform** (automate the management of containers - restarting them if they crash, scaling them up when traffic hits, updating them without downtime, ...)
* **Vagrant**: Virtual machine automation and management.
    * describle the installation, configuration in a `Vagrantfile`
    * usefull to have reproducible environments or shareable with a team
    * Key Concepts
        * **Box**: A pre-configured VM image (the equivalent of a Docker image, but for a full virtual machine). Thousands of them are available on Vagrant Cloud.
        * **Provider**: The underlying hypervisor used by Vagrant (VirtualBox, libvirt, VMware, etc.). 
        * **Provisioning**: Scripts (shell, Ansible, etc.) that run automatically during VM creation to install packages, configure services, and more.
* **K3s**: Ultra-lightweight Kubernetes distribution, optimized for production and edge environments.
* **Ingress**: an API object that manages **external access** to the services inside the cluster, typically HTTP and HTTPS traffic. It acts as a smart entry point or a routing table.
* **K3d**: A wrapper to run K3s inside Docker containers (ideal for local multi-cluster setups).
* **Argo CD**: A declarative, GitOps continuous delivery tool for Kubernetes.

---

## K8s vs Vagrant
**Vagrant manages Virtual Machines**, while **Kubernetes manages Containers.**

* **Vagrant** is used to automate the creation and configuration of **VMs** on my local laptop. Each VM acts like a completely separate computer with its own full operating system. Vagrant is used to quickly spin up a repeatable, clean sandbox environment.
* **Kubernetes (K8s)** is used to manage and orchestrate **Containers** (like Docker). Containers share the host computer's operating system, making them incredibly lightweight and fast. Kubernetes handles scaling these containers up or down and keeping them running across multiple machines.

---

## Part 1: K3s and Vagrant

The goal of this part is to set up a K3s cluster composed of two virtual machines managed by Vagrant: one **Server (Master)** node and one **Agent (Worker)** node.

### Virtual Machine Specifications

* **OS**: Stable Linux distribution of choice (e.g., Ubuntu 22.04 LTS or Debian 11/12).
* **Minimum Resources**: 1 CPU, 512 MB to 1024 MB of RAM per machine.
* **Network**: Passwordless SSH connection enabled between both machines.

| Role | Machine Name | Private IP | K3s Configuration |
| :--- | :--- | :--- | :--- |
| **Server** | `<login>S` | `192.168.56.110` | Controller / Master Mode |
| **Agent** | `<login>SW` | `192.168.56.111` | Agent / Worker Mode |

### Vagrant & Libvirt

**Step 1 — Check nested virtualization**

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo   # should return > 0
lsmod | grep kvm                      # should show kvm_intel (or kvm_amd) + kvm
```
If both checks pass, nested virtualization is active and KVM is usable inside the VM.

**Step 2 — Install libvirt/KVM**
```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils -y
sudo usermod -aG libvirt,kvm $USER   # avoid needing sudo for every libvirt command
```
A fresh SSH login is required for the group membership to take effect.

**Step 3 — Install Vagrant + the libvirt plugin**
```bash
sudo apt install vagrant -y
vagrant plugin install vagrant-libvirt
```
The plugin lets Vagrant drive libvirt as a provider.

**Step 4 — Initialize and launch a test VM**
```bash
mkdir ~/vagrant-test && cd ~/vagrant-test
vagrant init generic/debian12     # generates the Vagrantfile
vagrant up --provider=libvirt     # creates and starts the VM
vagrant ssh                       # connects into it
```
`vagrant init` only generates the config (`Vagrantfile`); `vagrant up` downloads the box if needed and creates the "domain" (libvirt's term for a VM), with default specs (2 CPUs, 2 GB RAM, dynamically allocated disk). Vagrant then waits for the VM to get an IP via DHCP before allowing the automatic SSH connection.


---

**Gotchas encountered**

**Issue: VM stuck on "Waiting for domain to get an IP address..." indefinitely**

The first `vagrant up --provider=libvirt` attempt hung forever waiting for an IP, with the VM showing as `running` in `virsh list --all` but never completing boot.

Troubleshooting steps taken, in order:

1. *Checked whether a `vagrant up` interruption (`Ctrl+C`) left a stale VM behind.* An earlier interrupted attempt did leave the domain running in libvirt without Vagrant's `.vagrant/` state knowing about it:
```bash
sudo virsh list --all
sudo virsh destroy <vm_name>
sudo virsh undefine <vm_name> --remove-all-storage
```
Useful to know, but not the root cause of the IP issue itself.

3. *Checked libvirt's `default` network (`virbr0`)* — found it `active` per `virsh net-list --all`, but at the interface level it was sitting in `NO-CARRIER` / `DOWN`:
```bash
ip a show virbr0
```
This turned out to be a red herring: `vagrant-libvirt` does **not** use the `default` network. It creates and manages its own separate network/bridge (in this case `virbr1`, range `192.168.121.0/24`), which doesn't show up in `virsh net-list` at all. Watching the wrong bridge wasted some time here.

4. *Found the real bridge via the tap interface*, which revealed the actual network in use:
```bash
ip a | grep -i vnet
# vnet was attached to "master virbr1", not virbr0
```
Once watching `virbr1` instead, the bridge showed `UP` / `LOWER_UP` with the tap interface correctly attached — so the network layer itself was healthy.

5. *Checked dnsmasq and DHCP leases* on the correct network:
```bash
ps aux | grep dnsmasq                              # confirmed a dnsmasq instance for vagrant-libvirt.conf
sudo find /var/lib/libvirt/dnsmasq/ -type f         # no .leases file ever appeared
```
dnsmasq was running and the bridge had carrier, but no lease was ever issued — pointing to the guest itself never completing a DHCP request, not a host-side networking problem.

6. *Tried the serial console* to see guest boot output directly:
```bash
sudo virsh console vagrant-test_default
```
No output at all, even after pressing Enter — the box's GRUB config likely wasn't redirecting boot output to `ttyS0`, so this didn't help, but it hinted the guest might not be booting normally at all.

**Root cause**: the box `generic/debian12` was resolving to a `ppc64le` (PowerPC) image for the libvirt provider on Vagrant Cloud, not `x86_64` — confirmed by checking the download URL in the `vagrant up` logs:
```
.../providers/libvirt/ppc64le/vagrant.box
```
QEMU was launching a VM for the wrong CPU architecture. It appeared as `running` in libvirt, but the guest OS could never actually execute, hence no DHCP request, no console output, and an indefinite hang.

**Fix**: switch to a different, properly maintained box for this provider:
```bash
vagrant box remove generic/debian12 --provider libvirt
sudo virsh vol-list default        # remove any leftover volume manually if present
sudo virsh vol-delete --pool default <volume_name>
```
Then in the `Vagrantfile`, replace:
```ruby
config.vm.box = "generic/debian12"
```
with:
```ruby
config.vm.box = "debian/bookworm64"
```
This box correctly resolves to `providers/libvirt/amd64/vagrant.box`, matching the host's `x86_64` architecture. `vagrant up --provider=libvirt` then completed normally: IP obtained, SSH key exchanged, NFS shared folder mounted, machine ready.


### File Structure

```text
├── Part1/
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── server_setup.sh
│   │   └── agent_setup.sh

```

### Deployment Guide

1. **Launch the Infrastructure**:
Navigate to the `Part1` directory and boot up the VMs:

```bash
   vagrant up --provider=libvirt

```

2. **Connect to the Machines**:

```bash
   # Connect to the Server node
   vagrant ssh <login>S
   
   # Connect to the Agent node
   vagrant ssh <login>SW

```

3. **Verify the Cluster** (from the Server node):

```bash
   sudo kubectl get nodes -o wide

```


### Tips
To make the worker node (`<login>SW`) join the master node (`<login>S`) automatically, I will need to extract the cluster token generated by K3s on the server. It is usually located at `/var/lib/rancher/k3s/server/node-token`. The transfer can be automated between VMs using Vagrant's provisioning shell scripts.

### Tests for each steps
**Step 1: VMs created and reachable via Vagrant**

Check both VMs were created and are running:
```bash
vagrant status
```
Expected: both `lbuissonS` and `lbuissonSW` show `running (libvirt)`.

Confirm at the libvirt level too:
```bash
sudo virsh list --all
```
Expected: both domains listed with state `running`.

Confirm SSH access to each VM via Vagrant:
```bash
vagrant ssh lbuissonS    # should drop into a shell, then `exit`
vagrant ssh lbuissonSW   # should drop into a shell, then `exit`
```

**Step 2: private network connectivity between the two VMs**

From inside the server, confirm the private network interface has the expected IP:
```bash
vagrant ssh lbuissonS
ip a
```
Expected: an interface (e.g. `eth1`) with `192.168.56.110/24`.

Ping the agent from the server:
```bash
ping -c 3 192.168.56.111
```
Expected: `0% packet loss`.

Exit and repeat in the other direction:
```bash
exit
vagrant ssh lbuissonSW
ping -c 3 192.168.56.110
```
Expected: `0% packet loss`.

**Step 3: SSH connections between VMs**
testing doing it manually - inside one VM
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

inside the other VM
```bash
mkdir -p ~/.ssh
echo "ssh_key" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Go back in the first VM
```bash
ssh -o StrictHostKeyChecking=no vagrant@192.168.56.111 #StrickHostKeyChecking=no avoid being asked if I am sure to continue
```

How to automatize with Vagrantfile ?
   * use a triger that read on the main VM the SSH of one nested VM to copy it into the other nested VM


**Step 4: cluster Kubernetes**


```bash
vagrant ssh lbuissonS

```

```bash
sudo kubectl get nodes -o wide

```

```bash
sudo kubectl get pods -A

```

---

## Part 2: K3s and 3 Simple Applications

Deploying and routing applications within the K3s cluster created in Part 1 using **Ingress**, **Services**, and **Deployments**.

* Deployment of 3 distinct, lightweight applications (App1, App2, App3).
* Configuration of an Ingress Controller (Traefik, bundled with K3s) to route traffic based on hostnames or specific paths (e.g., `app1.local`).
* Managing internal cluster routing and Pod high availability.

*(Documentation to be expanded during implementation)*

---

## Part 3: K3d and Argo CD

Transitioning into a fully containerized local environment using **K3d** to simulate a multi-node cluster, coupled with a modern **GitOps** pipeline via **Argo CD**.

* Creating a K3s cluster inside Docker using K3d.
* Installing and exposing Argo CD for continuous deployment.
* Setting up a Git repository as the "Source of Truth" to automatically sync the cluster's state with your declarative YAML configurations.

*(Documentation to be expanded during implementation)*

---

## Useful Commands

* `vagrant status`: Check the current status of your VMs.
* `vagrant halt`: Gracefully shut down the VMs.
* `vagrant destroy -f`: Completely delete the VMs to reset the environment.
* `vagrant provision`: Force to replay the provision/script part on the VM
* `kubectl get pods -A`: List all running pods across all namespaces.

---

## Clean up if IP problem
#### 1. Nettoyage de Vagrant

```bash
# Force la destruction des VM gérées par le Vagrantfile local
vagrant destroy -f

# Supprime l'historique et les états locaux de Vagrant (efface le cache)
rm -rf .vagrant/

```

#### 2. Suppression des "VM fantômes" dans libvirt (avec `virsh`)

Si Vagrant a planté, les VM restent parfois bloquées dans libvirt. On les élimine manuellement :

```bash
# Force l'extinction des deux VM si elles tournent en tâche de fond
sudo virsh destroy Part1_lbuissonS 2>/dev/null
sudo virsh destroy Part1_lbuissonSW 2>/dev/null

# Supprime la définition/existence des VM dans libvirt
sudo virsh undefine Part1_lbuissonS 2>/dev/null
sudo virsh undefine Part1_lbuissonSW 2>/dev/null

# Libère l'espace disque en supprimant les disques virtuels (.img) restants
sudo virsh vol-delete --pool default Part1_lbuissonS.img 2>/dev/null
sudo virsh vol-delete --pool default Part1_lbuissonSW.img 2>/dev/null

```

#### 3. Relance propre du réseau et du DHCP

C'est l'étape qui corrige le problème d'attribution d'IP :

```bash
# Redémarre le service libvirt pour rafraîchir le serveur DHCP interne
sudo systemctl restart libvirtd

# Force le démarrage du réseau par défaut (celui qui donne l'IP SSH)
sudo virsh net-start default 2>/dev/null
sudo virsh net-autostart default

# (Optionnel) Vérifie que les réseaux nécessaires sont bien à l'état "active"
sudo virsh net-list --all

```


---

## Definition
\
**QEMU**
C'est le programme qui émule/exécute réellement la VM. Quand on a `qemu-system-x86_64` dans les logs, c'est le processus qui fait tourner ma VM — il simule un CPU, de la RAM, des disques, une carte réseau, etc. C'est le moteur d'exécution.

**KVM**
C'est une extension du noyau Linux qui permet à QEMU d'utiliser directement les fonctionnalités de virtualisation matérielle du CPU (VT-x sur Intel, AMD-V sur AMD) plutôt que de tout émuler en logiciel (lent). QEMU + KVM = la VM tourne presque à la vitesse native, au lieu d'être émulée bit par bit.

**libvirt**
C'est une couche de gestion par-dessus QEMU/KVM. Plutôt que de taper des commandes `qemu-system-x86_64` à la main avec pleins d'options (comme on l'a vu dans le log), libvirt donne des outils plus simples (`virsh`, `virt-manager`) pour créer, démarrer, arrêter, configurer des VMs, des réseaux virtuels, etc. C'est un intermédiaire pratique.

**Vagrant**
Encore une couche au-dessus de libvirt (ou VirtualBox, etc.) : il automatise la création de VMs à partir d'un simple fichier texte (`Vagrantfile`), en pilotant libvirt.

**Bridge (pont réseau)**
Un bridge, c'est comme une prise multiple réseau virtuelle : il relie plusieurs interfaces réseau ensemble pour qu'elles puissent communiquer comme si elles étaient sur le même câble. `virbr0`, `virbr1` sont des bridges virtuels créés par libvirt (chaque VM s'y connecte pour avoir accès au réseau).

**vnet (ou "tap interface")**
C'est l'interface réseau virtuelle spécifique à **une** VM, qui la connecte au bridge. Si `virbr0` est la prise multiple, `vnet2` est le câble qui relie ma VM précise à cette prise. Chaque VM a sa propre interface vnet.

**dnsmasq**
C'est un petit service léger qui fait deux choses : DHCP (distribuer des IP automatiquement aux VMs qui se connectent au bridge) et DNS (résolution de noms). Quand une VM démarre et demande une IP, c'est dnsmasq qui lui en attribue une.

**Pour résumer :**

CPU (virtualisation matérielle) → KVM (accès kernel à cette virtualisation) → QEMU (émule la VM complète) → libvirt (gère QEMU proprement) → Vagrant (automatise libvirt avec un fichier de config) → Vagrantfile 
En parallèle pour le réseau : bridge (virbr0/virbr1) = le switch virtuel, vnet = le câble de chaque VM vers ce switch, dnsmasq = le serveur qui distribue les adresses IP sur ce réseau.

---

## Resources
   * Libvirt
      * https://libvirt.org/docs.html
      * https://jamielinux.com/docs/libvirt-networking-handbook/
      * https://libvirt.org/formatnetwork.html
      * https://wiki.archlinux.org/title/Libvirt
   * Vagrant+Libvirt
      * https://vagrant-libvirt.github.io/vagrant-libvirt/configuration.html
      * https://github.com/vagrant-libvirt/vagrant-libvirt
      * https://medium.com/@joseignacio.carretero/vagrant-libvirt-plugin-57f253887308
   * Vagrant
      * https://fedoramagazine.org/vagrant-beyond-basics/
      * https://developer.hashicorp.com/vagrant/docs/triggers/usage
   * Dnmasq
      * https://thekelleys.org.uk/dnsmasq/doc.html
   * SSH
      * https://medium.com/@favboladale/how-to-connect-from-one-machine-to-another-using-ssh-vagrant-6878e26d9091
      * https://stackoverflow.com/questions/73500827/vagrant-multi-vm-ssh-connection-setup-works-on-one-but-not-the-others
      * https://www.portnox.com/cybersecurity-101/authentication/ssh-passwordless-login/
   * Vagrant+K3s
      * https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
      * https://web-docs.gsi.de/~vpenso/notes/posts/kubernetes/vagrant-k3s.html
