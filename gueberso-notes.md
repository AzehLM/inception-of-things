# personal notes

# Kubernetes (K8s)

Orchestrateur de conteneurs. Gere automatiquement le deploiement, la mise a l'échelle et l'état d'un ensemble d'applications conteneurisées. Concretement on dit "je veux X instances de cette application" et il les maintient dans cet état, meme quand ca crash

### Abstraction

- **Pod**: unité de base. Un pod contient un ou plusieurs conteneurs qui partagent lememe reseau et le meme stockage
- **Deployment**: Un object qui gere des pods. Décrit combien de replicats, quelles images utilises etc. S'assure que le nombre de pod voulu tourne a tout instant. Si un pod meurt, le Deployement en relance un
- **ReplicatSet**: créé automatiquement par un Deployment, il est le responsable du maintient du bon nombre de replicas de pods en vie. (On peut le voir via les outputs de `kubectl`)
- **Service**: K8s donne a chaque pod une IP interne qui change a chaque recreation. Un Service fournit une IP et un nom DNS stable qui redirigent vers les pods. C'est l'abstraction réseau interne des clusters
- **NameSpace**: un espace de noms logique qui partitionne un cluster (possible d'avoir plusieurs environnement dans un meme cluster physique (dev, prod, argocd, etc.)).
- **Ingress**: un object qui expose des services HTTP/HTTPS vers l'exterieur d'un cluster. Avec du routage par nom de domaine (`app1.com`, `app2.com`, etc.)
- **kubectl**: Kubernetes CLI. On interagis avec nos cluster avec lui (`kubectl get pods`, `kubectl apply -f file.yaml`, etc.). Les fichiers de config K8s sont en yaml


## K3s

Distro K8s allégée. C'est une version compressé en un binaire, pensé pour des environnements restreint (IoT, VMs avec peu de RAM, etc.). Inclut le scheduler, le controller manager, le server API, Traefik comme Ingress controller par defaut.

- **Mode server (controller)**: node maitre du cluster. Il decide ou placer les pods, surveille l'état du cluster, expose l'API K8s
- **Mode agent**: node worker. Il recoit des instructions server et fait tourner les pods qui lui sont assignés. Ce connecte avec un **token** au server au démarrage


# Vagrant

Outil qui permet de créer et gérer des machines virtuelles de facon reproductible (via un ficher de config: `Vagranfile`). Ce fichier de config est une description en Ruby des VMs: OS, réseau, ressources, scripts de provisioning, etc. Useful commands:
- `vagrant up`
- `vagrand ssh machine_name`

Useful key config:
- `config.vm.network`: pour l'ID dédiée
- `config.vm.provider`: pour le provider (VirtualBox, ou Docker ? + nom, RAM, CPU)
- `config.vm.provision "shell"`: pour exécuter des scripts au lancement

# K3d

Wrapper qui fait tourner K3s a l'intérieur de Docker containers. K3d simule un cluster K8s multi-noeuds dans des containers docker sur la machine locale. Beaucoup plus léger et rapide a instancier

#### Différences clé:

|   | K3s | K3d |
|---|---|---|
| tourne sur | Une VM / Machine réelle   | Des containers Docker |
| Usage | Déploiement réel | Développement local |
| Rapidité | Lent a bootstrapper | Rapido presto |
| Prérequis | Vagrant / Linux | Docker |

# Argo CD

Outil **GitOps**, paradigme dans lequel *un repo Git est la source de vérité de l'état de l'infrastructure*.
C'est a dire que Argo CD surveille en continu un repo Git et synchronise automatiquement le cluster pour qu'il corresponde a l'état du actuel du repo.
C'est du CD piloté par Git, sans pipeline CI/CD. La différence avec une mise a jour avec `kuberctl apply` c'est que c'est *déclaratif*, permanent et auditable via l'historique Git.
L'interface d'Argo CD montre l'état de synchronisation, les différences entre ce qui tourne dans le/les clusters et l'état Git (+ historique de déploiement)



## Concepts un peu plus détaillé

### Ingress - routeur HTTP du cluster

Un Ingress permet de controler comment le traffic web atteint le workload (pods/applications).
L'Ingress est l'entrypoint de nos clusters. Il permet de consolider une routine de regles en une ressource unique. Il est le seul listener des intereactions avec notre cluster. (D'ou l'utilisation de Traefik/Nginx/Caddy comme Ingress (dans le cas de workload HTTP))

### cgroups - Control Groups (noyau Linux)

Les control groups sont une des feature du noyau Linux qui permet de **limiter, isoler, monitorer** les ressources consommées par des gorupes de processus.
Quand on utiliser une distribution OpenRC (Alpine), on utiliser rc-group (Service OpenRC)  pour monter/initialiser les cgroups au boot


# Token secret

`/var/lib/rancher/k3s/server/node-token`

Token secret qui sert de secret partagé entre server et agents.

On en a besoin pour s'authentifier au server

```sh
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://x \
  --token <contenu_du_node-token>```
```

Avec Ansible on peut le récupérer via une tache `slurp` ou `fetch` ou encore via les `hostvars` pour partager une value entre plusieurs plays d'un meme playbook

[k3s token](https://docs.k3s.io/cli/token)



### P2

`service.yml` != `deployment.yml`

C'est le **deployment** qui indique le nombre de pods de cette image. Le service est une **abstraction réseau** c'est lui qui donne une IP stable + un nom DNS interne a un group de pods (dont les IP changent a la recréation).

La chaine logique de la P2 c'est:

`ingress` (entrée HTTP, routage par Host) -> `service` (point d'entré stable, loadbalancing interne) -> `deployment` (configuration des instances réelles de l'app)
