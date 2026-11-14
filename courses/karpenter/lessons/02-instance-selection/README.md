# Pick instance types with NodePool requirements

## Concept

A NodePool doesn't list machines; it describes the **shape** of the machines
Karpenter may buy. Each requirement is a node-label key, an operator (`In`,
`NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`, `Gte`, `Lte`) and values.
Karpenter keeps every instance type that matches all of them, then lets the
pods narrow it further.

Labels you can use before a node exists (the cloud provider knows them for
every instance type):

| Key | Example |
|---|---|
| `node.kubernetes.io/instance-type` | `m7g.xlarge` |
| `kubernetes.io/arch` | `amd64`, `arm64` |
| `karpenter.sh/capacity-type` | `on-demand`, `spot` |
| `topology.kubernetes.io/zone` | `us-west-2a` |
| `karpenter.k8s.aws/instance-category` | `c` compute, `m` general, `r` memory, `g`/`p` GPU |
| `karpenter.kwok.sh/instance-family` | `m7g` |
| `karpenter.kwok.sh/instance-cpu`, `-memory` | `4`, `16Gi` |

Prefer broad rules ("category m, at least 4 vCPUs") over a fixed list of
types: the more types Karpenter may pick from, the cheaper the fit and the
better the odds that one is available. `Gt`/`Lt` compare integer label
values, so `instance-cpu Gt 3` means "4 vCPUs or more".

How it chooses: Karpenter packs the pending pods into as few new nodes as
possible. For each node it lists every instance type that fits the pods'
summed requests (plus the system reserve), and the provider launches the
cheapest. One big node is often as cheap as several small ones (prices are
roughly linear in size), wastes less on per-node overhead, and leaves
headroom for the next pod; a minimum size keeps you from a fleet of tiny
nodes.

When no instance type survives, the pods stay Pending and Karpenter says why
in an event on the pod (`FailedScheduling` from `karpenter`).

## The situation

NodePool `general` was copied from an old cluster: it allows only `m5.*`
types, which this cloud doesn't offer. In namespace `apps`, `api` (6 × 500m
CPU, 1 GiB) and `worker` (1 × 12 CPU, 24 GiB) are Pending. Both images are
multi-arch.

## Your task

Change NodePool `general` to the platform policy:
- arm64 (Graviton): `kubernetes.io/arch` In `[arm64]`
- general purpose only: `karpenter.k8s.aws/instance-category` In `[m]`
- xlarge or bigger: a `Gt` (or `Gte`) requirement on
  `karpenter.kwok.sh/instance-cpu` so nothing under 4 vCPUs is launched
- keep `karpenter.sh/capacity-type` In `[on-demand]` and `limits.cpu: 64`
- drop the `node.kubernetes.io/instance-type` list

Result: `api` (6) and `worker` (1) Running; every Karpenter node arm64,
category `m`, with at least 4 vCPUs, from NodePool `general`.

Rules: don't change the workloads (replicas, requests, and no
nodeSelector/affinity); don't create nodes yourself. Nodes appear ~5 s after
the fix. Before applying, guess which type(s) Karpenter will pick.

## Useful commands

    kubectl -n apps describe pod -l app=worker | tail -5
    kubectl -n karpenter get cm instance-types -o jsonpath='{.data.catalog\.txt}'
    kubectl edit nodepool general
    kubectl get nodeclaims -o wide
    kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.kwok.sh/instance-cpu,kubernetes.io/arch
    kubectl -n karpenter logs deploy/karpenter | grep 'created nodeclaim'

When you think you're done: `kdrill verify`

## On a real cluster

On AWS the equivalents are `karpenter.k8s.aws/instance-family`,
`instance-cpu`, `instance-memory`, `instance-generation`, `instance-size` and
more (the KWOK provider names its own `karpenter.kwok.sh/*`; kdrill adds
`karpenter.k8s.aws/instance-category` and the GPU labels to its catalogue so
you can practise the real keys). Changing a NodePool's requirements doesn't
touch running nodes immediately; nodes that no longer match are *drifted*
and replaced (lesson 10).

## Read more

- https://karpenter.sh/docs/concepts/nodepools/
- https://karpenter.sh/docs/concepts/scheduling/
- https://karpenter.sh/docs/reference/instance-types/
