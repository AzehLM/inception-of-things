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
