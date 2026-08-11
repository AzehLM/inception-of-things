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

## verify the default ingress

```sh
vagrant ssh <nameS> -c "kubectl get pods -A | grep traefik"
vagrant ssh <nameS> -c "kubectl get svc -A | grep traefik"
vagrant ssh <nameS> -c "kubectl get ingressclass"
```



# Part 2 - K3s and Mettre au propre

vagrant up
vagrant ssh guebersoS
kubectl get nodes
kubectl get all -n p2
kubectl get ingress -n p2
curl -H "Host: app1.com" http://192.168.56.110


# Part 3 - K3d and mettre au propre aussi j'avais oublié

Commandes a faire sur la machine hote
```sh
# Récupère le secret mdp pour ce log via l'UI Argo CD (et probablement depuis le CLI aussi a voir)
# Doit etre decoder depuis la base64
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Permet de forward ArgoCD sur le port 8080
kubectl port-forward svc/argocd-server -n argocd 8080:443
# il faut également rajouté dans l'onglet PORTS la forwarded address localhost:8080 ensuite
```
