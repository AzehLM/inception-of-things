# Personal notes - Inception of Things

## Kubernetes (K8s)

Container orchestrator. Automatically handles deployment, scaling, and state of
several containerized applications, even when they crash.

### Core abstractions

- **Pod**: base unit. A pod is made of one or several containers sharing the
  same network and storage.
- **Deployment**: an object managing pods. Describes the number of replicas,
  which image is used, etc. Makes sure the wanted number of pods is running at
  any time - if a pod dies, the Deployment relaunches another one.
- **ReplicaSet**: created by the Deployment, it's responsible for maintaining
  the right number of live pod replicas (visible via `kubectl` output).
- **Service**: K8s gives each pod an internal IP that changes on re-creation.
  A Service provides a stable IP and DNS name that redirect to the pods - the
  internal network abstraction of a cluster.
- **Namespace**: a logical namespace that partitions a cluster. Makes it
  possible to run several environments in the same physical cluster (dev,
  prod, argocd, etc.).
- **Ingress**: an object that exposes HTTP/HTTPS services outside the cluster,
  with routing by domain name.
- **kubectl**: the Kubernetes CLI. Used to interact with a cluster
  (`kubectl get pods`, `kubectl apply -f file.yaml`, etc.). K8s manifests
  (config files) are written in YAML.

## K3s

Lightweight K8s distro, compiled into a single binary, designed for
constrained environments (IoT, low-RAM VMs, etc.). Bundles the scheduler, the
controller manager, the API server, and Traefik as the default Ingress
controller.

- **Server mode (controller)**: the cluster's master node. Decides pod
  placement, watches cluster state, exposes the K8s API.
- **Agent mode**: worker node. Receives instructions from the server and runs
  the pods assigned to it. Connects to the server at startup using a token.

## Vagrant

Tool to create and manage VMs through a config file (`Vagrantfile`). This file
is a Ruby description of the VMs: OS, network, resources, provisioning
scripts, etc.

Useful key config:
- `config.vm.network`: dedicated IP
- `config.vm.provider`: specify provider (VirtualBox, libvirt...), RAM, CPU
- `config.vm.provision "shell"` / `"ansible"`: specify provisioning type and
  parameters

## K3d

Wrapper that runs K3s inside Docker containers. K3d simulates a multi-node K8s
cluster using Docker containers on the local machine - much lighter and
faster to spin up than a VM-based setup.

K3d isn't just "K3s but lighter": the key difference is that it runs inside
Docker containers rather than on a VM. Each K3d "node" is actually a Docker
container. That's why K3d is so fast to bootstrap - there's no full OS boot
involved.

|              | K3s                     | K3d               |
|--------------|--------------------------|--------------------|
| Runs on      | A VM / real machine      | Docker containers  |
| Usage        | Real-world deployment    | Local development  |
| Speed        | Slow to bootstrap        | Very fast          |
| Requirements | Vagrant / Linux          | Docker             |

## Argo CD

A **GitOps** tool, built on the paradigm where a Git repo is the single source
of truth for infrastructure state. Argo CD continuously watches a Git repo and
automatically syncs the cluster to match the repo's current state - Git-driven
CD, with no CI/CD pipeline involved.

The difference from a manual `kubectl apply` update: it's declarative,
persistent, and auditable through Git history. The Argo CD UI shows sync
status, the diff between what's running in the cluster(s) and the Git state,
plus deployment history.

## Deeper concepts

### Ingress - the cluster's HTTP router

An Ingress controls how web traffic reaches the workload (pods/applications).
It's the entrypoint of the cluster, consolidating a set of routing rules into
a single resource - the single listener for interactions with the cluster
(hence using Traefik/Nginx/Caddy as the Ingress controller for HTTP
workloads).

### cgroups - Control Groups (Linux kernel)

Control groups are a Linux kernel feature that lets you limit, isolate, and
monitor the resources consumed by groups of processes. On an OpenRC distro
(Alpine), the `cgroups` OpenRC service is used to mount/initialize cgroups at
boot.

### K3s node token

`/var/lib/rancher/k3s/server/node-token`

Shared secret between the server and agents, needed for agents to
authenticate against the server:

```sh
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://x \
  --token <node-token-content>
```

In Ansible, it can be retrieved via a `slurp` or `fetch` task, or shared
across plays within the same playbook via `hostvars`.
([k3s token docs](https://docs.k3s.io/cli/token))

---

## P2 notes

`service.yml` != `deployment.yml`

It's the **Deployment** that specifies how many pods run a given image. The
**Service** is a network abstraction: it provides a stable IP + internal DNS
name for a group of pods (whose individual IPs change on re-creation).

The logical chain in p2 is:

`Ingress` (HTTP entrypoint, Host-based routing) -> `Service` (stable entrypoint,
internal load balancing) -> `Deployment` (actual app instance configuration)

`protocol: TCP`, not HTTP, because:
- TCP = how bytes flow between clients and pods
- HTTP = the content of those bytes, layered on top of TCP

It's not the Service's job to understand or route based on request content -
that's the Ingress's job, translating HTTP headers (for virtual hosting, for
example).

---

## P3 notes

**What is an Argo CD `Application`?** A CRD (CustomResourceDefinition)
instance that binds together a Git repo + path, a target cluster, and a
target namespace.

Simple analogy:
- A CRD is like a class/struct definition.
- A CR (Custom Resource) is an instance of that class.
- The Argo CD controller is the program that reads that instance and acts on
  the cluster accordingly.

**Sync status vs Health status** - two different axes:
- *Sync status* (`Synced` / `OutOfSync`): compares the desired state (Git)
  against what's actually applied to the cluster.
- *Health status* (`Healthy`, `Progressing`, `Degraded`, ...): checks whether
  the resources are actually working as expected (e.g. are the pods up and
  ready), independently of whether they're in sync with Git.

**Manual vs automatic sync**: without `syncPolicy.automated`, a detected
`OutOfSync` state requires an explicit `argocd app sync` (or a UI click) to
reconcile. With `automated` enabled, Argo CD reconciles on its own as soon as
a diff is detected (see below).

**Why two namespaces?**
- `argocd`: hosts Argo CD's own internal components - `argocd-server`
  (API/UI), `repo-server`, `application-controller`, `redis`, etc. This is the
  deployment tool itself.
- `dev`: the deployment *target* namespace - where Argo CD creates the actual
  Kubernetes objects (`Deployment`, `Service`, etc.) for the app being
  managed.

Everything isn't in the same namespace because Argo CD is meant to be able to
deploy to any target cluster/namespace, following the principle of isolating
the CD tool from what it deploys. A single Argo CD instance could therefore
manage multiple target namespaces (or even multiple clusters) - an
architecture designed to scale.

**Reconciliation loop** - what happens when the Git repo changes:
1. `repo-server` polls the Git repo (every 3 minutes by default).
2. Compares the Git content against the live cluster state.
3. If a diff is detected, the app's status flips to `OutOfSync`.
4. If auto-sync is enabled, Argo CD applies the change automatically;
   otherwise a manual `Sync` is required.
   ([auto-sync docs](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/))

### `--server-side --force-conflicts`

A classic `kubectl apply` (client-side) fails on the official Argo CD
manifest: it stores the previous configuration in the
`kubectl.kubernetes.io/last-applied-configuration` annotation, capped at
262144 bytes - and Argo CD's CRDs exceed that. Server-side apply bypasses this
by tracking field ownership on the server instead of that annotation.

`--force-conflicts` is necessary because Argo CD's own controllers modify some
of these fields once running; without this flag, a re-apply would fail on a
field-ownership conflict.

### NodePort + k3d loadbalancer instead of an Ingress

p2 explicitly required Host-based HTTP routing (app1.com, app2.com,
app3.com) via an Ingress. p3 only has one application to expose, with no
hostname-routing requirement. A `NodePort` is enough, exposed via k3d's
load-balancer port mapping (`-p 8888:30888@loadbalancer` in `setup.sh`).

### `syncPolicy`: `automated` + `prune` + `selfHeal`

- `automated.enabled`: Argo CD synchronizes without manual intervention once
  it detects a diff between Git and the cluster (Git = source of truth).
- `prune: true`: any resource removed from the repo is removed from the
  cluster.
- `selfHeal: true`: the actual GitOps guarantee. Without it, Argo CD only
  fixes the cluster when *Git* changes; with `selfHeal`, a `kubectl
  edit`/`delete` done directly on the cluster gets reverted back to the
  declared Git state.
- `syncOptions: [CreateNamespace=true]`: the `dev` namespace is created
  automatically by Argo CD before the app is deployed. This choice comes
  directly from a bug hit in p2 (`namespace "x" not found` - manifest
  application order matters). With this option, the only namespace created
  manually is `argocd`; Argo CD then creates `dev` itself. Fixes the ordering
  issue without a manual step.

---

## Reference links

- [K3s CLI token docs](https://docs.k3s.io/cli/token)
- [Argo CD installation docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD repo-server reference](https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-repo-server/)
- [Argo CD auto-sync docs](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Kubernetes manifest/YAML quick reference](https://institute.sfeir.com/en/kubernetes-training/manifests-yaml-kubernetes-reference-quick/)
- [Traefik PR #3404](https://github.com/traefik/traefik/pull/3404) - context on Traefik's Ingress behavior
- [k3d by Stephane Robert](https://blog.stephane-robert.info/docs/conteneurs/orchestrateurs/k3d/#architecture-dun-cluster-k3d)
