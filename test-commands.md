*Commands will be reusable for each Parts (learning curve ykwim)*

# Part 1 — K3s and Vagrant

## VM states

```sh
vagrant status
```
Vérifie that VMs are in the `running` state

## VMs Hotname

```sh
vagrant ssh <nameS> -c "hostname"
vagrant ssh <nameSW> -c "hostname"
```
Returns the hostname of the VM running

## IP address of the private interface

```sh
vagrant ssh <nameS> -c "ip a show eth1"
vagrant ssh <nameSW> -c "ip a show eth1"
```

`eth1` adapter depending on the real interface name (sometimes `eth0` is the default Vagrant NAT interface thats why I base my commands on `eth1` )

## SSH Connection without password requirement

```sh
vagrant ssh <nameS>
```
```sh
vagrant ssh <nameSW>
```
Vagrant handles SSH key injection automaticaly by default

## Checking VMs can see each other on their private network


```sh
vagrant ssh <nameS> -c "ping -c 3 192.168.56.111"
vagrant ssh <nameSW> -c "ping -c 3 192.168.56.110"
```

## Allocated ressources (CPU / RAM)

```sh
vagrant ssh <nameS/SW> -c "nproc"
vagrant ssh <nameS/SW> -c "free -h"
```

## Distribution version

```sh
vagrant ssh <nameS/SW> -c "cat /etc/os-release"
```

## Nodes role (Controller / worker)

```sh
vagrant ssh <nameSW> -c "sudo k3s kubectl get nodes -o wide"
```
<nameS> has to be `control-place,master` and <nameSW> no role. Both with the `Ready` state

## kubectl working without sudo

```sh
vagrant ssh <nameS> -c "kubectl get nodes"
```
