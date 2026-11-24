# Put the database on SSD

## Concept

By default the scheduler may put a pod on any node with enough free resources.
To steer it you use **node labels** and rules in the pod spec that match them.

**nodeSelector** is the simplest form: a map of labels that a node must have.

    nodeSelector:
      disktype: ssd

It is always a hard requirement — if no node matches, the pod stays `Pending`.

**Node affinity** (`spec.affinity.nodeAffinity`) is the expressive version. It
has two flavours:

- `requiredDuringSchedulingIgnoredDuringExecution` — a hard rule, like
  nodeSelector but with operators (`In`, `NotIn`, `Exists`, `DoesNotExist`,
  `Gt`, `Lt`) and OR-able terms.
- `preferredDuringSchedulingIgnoredDuringExecution` — a soft rule. Each entry
  has a `weight` (1–100) and a `preference`; nodes that match score higher.
  The scheduler tries to honour it but will happily place the pod elsewhere.

"IgnoredDuringExecution" means the rule is only checked when scheduling: if a
node's labels change later, running pods are not evicted.

Rule of thumb: use a **hard** rule when running in the wrong place is a bug
(the database needs fast disks), and a **soft** rule when it is merely nicer
(a cache is faster near its clients, but works anywhere).

Nodes also carry well-known labels such as `topology.kubernetes.io/zone` and
`kubernetes.io/hostname`; you can match those like any other label.

## The situation

The cluster has four worker nodes in two zones, each with SSD or HDD disks:

    kubectl get nodes -L topology.kubernetes.io/zone,disktype

Two Deployments run with no placement rules at all: `db` (2 replicas) and
`cache` (2 replicas). The database is slow because some of its pods sit on HDD
nodes.

## Your task

1. `db`: every pod must run on a node with `disktype=ssd`, enforced by a
   **hard** rule in the pod template (a `nodeSelector`, or a required node
   affinity using `In` with value `ssd`).
2. `cache`: add a **soft** preference for zone `a`
   (`preferredDuringSchedulingIgnoredDuringExecution`, key
   `topology.kubernetes.io/zone`, operator `In`, values containing `a`). It
   must not have a nodeSelector or required rule on the zone label.

Rules:
- Keep 2 replicas of each, all ready.
- Don't change the nodes: no relabelling, no new nodes.

## Useful commands

    kubectl get nodes -L topology.kubernetes.io/zone,disktype
    kubectl get pods -o wide
    kubectl explain deploy.spec.template.spec.affinity.nodeAffinity
    kubectl edit deploy db
    kubectl patch deploy db --type merge -p '...'

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes-using-node-affinity/
