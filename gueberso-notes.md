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

# K3s vs K3d

K3d n'est pas juste K3s en plus léger, c'est K3d **qui tourne a l'intérieur de containers Docker** plutot que sur une VM. Chaque "node" K3d est en fait un container Docker. C'est pour ca que K3s est plus rapide a instancier, car il n'y a pas de boot d'OS complet.

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
`protocol: TCP` et pas `HTTP` car:
- TCP = comment les octets circulent entre clients et pods
- HTTP = contenu de ces octets, au-dessus de TCP
Ce n'est pas le role du Service de comprendre ou de faire du routage basé sur le contenue des requetes. C'est l'Ingress qui s'occupe de faire la transcription des headers HTPP (pour du virtual hosting par exemple)


# DOC POUR QUAND JE SUIS PAS A L'ECOLE

https://github.com/traefik/traefik/pull/3404
https://institute.sfeir.com/en/kubernetes-training/manifests-yaml-kubernetes-reference-quick/
https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/


### P3

TODO:

- [ ] Script vérification dépendences présentes
- [ ] Script installation/desinstallation des dépendences -> (docker, k3d, argocd, kubectl, cli argocd ? plus facile de faire les tests que depuis l'UI web ?)
- [ ] Namespaces -> dev/argocd (ou **Argo CD ?**)
- [ ] Deployer app via wil dockerhub [images](https://hub.docker.com/r/wil42/playground)
- [ ] Le reste apres


- Qu'est-ce qu'un **Application** Argo CD ? (Object CRD qui lie repo Git + path + cluster cible + namespace (faire diagramme))
- Différence entre **Synced** et **OutOfSync**, meme chose pour les état **Healthy** (Progressing, Degraded, etc) en quoi c'est différent de **Synced** (compare l'état désire vs Git, l'autre check l'état réel des ressources vs ce qui est attendu (pods))
- Sync manuel vs sync auto

Pourquoi 2 namespaces ?
- `argocd`: contient les composants internes d'ArgoCD (server API, repo-server, controller d'application, redis, etc.) -> c'est l'outil de deploiement (mais est-ce que c'est le serveur ?)
- `dev`: le namespace **cible du deploiment** -> la ou Argo CD va créer les objects Kubernetes (`Deployment`, `Service`, etc)

On ne met pas tout dans le meme namespace car ArgoCD est censé pouvoir déployer vers **n'importe quel cluster/namespace cible** pour répondre au principe d'isolation entre outil de CD et ce qu'il déploie. On pourrait alors avoir plusieurs namespace gérés par le meme Argo CD. C'est une architecture faire pour scaler

Quand on effectuera des modifications sur le repo, coté ArgoCD il se passera:
- **[Repo-server](https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-repo-server/)** poll le repo Git (toute les 3min par defaut)
- Compare le contenu Git avec l'état vivant du cluster
- Détecte une différence ? change l'état de l'app a `OutOfSync`
- Si l'auto-sync est activé, l'applique automatiquement sinon il faut `Sync` a la main.
- [doc](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)

