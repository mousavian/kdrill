# Capstone: why is my GPU workload not running?

## Concept

When a GPU workload doesn't run, the cause is at one of a few layers, and
each layer leaves evidence somewhere else:

| Layer | Symptom | Where to look |
|---|---|---|
| Admission / quota | no pod exists at all | `kubectl describe rs` / `job`: `FailedCreate` |
| Queueing (Kueue) | Job suspended, 0 pods | `kubectl get workloads`, `describe workload` |
| Scheduling: filters | pod `Pending` | pod events: `FailedScheduling` |
| DRA allocation | pod `Pending`, claim unallocated | pod events, `kubectl get resourceclaim -o yaml` |

A `FailedScheduling` message lists the reason per node, e.g.

    0/4 nodes are available: 1 Insufficient nvidia.com/mig-1g.5gb,
    1 node(s) didn't match Pod's node affinity/selector,
    2 node(s) had untolerated taint {nvidia.com/gpu: present}.

Read it node by node: every node must fail for *some* reason, and the one you
expected to work tells you what's wrong. Common GPU causes:

- **Taints**: GPU nodes are usually tainted (`nvidia.com/gpu=present:NoSchedule`
  here) so only pods that tolerate it land there.
- **Label values**: GFD values are exact strings (`NVIDIA-H100-80GB-HBM3`).
  Check with `kubectl get nodes -L nvidia.com/gpu.product`.
- **Resource names**: a pod asking for a MIG profile or resource that no node
  advertises waits forever with `Insufficient <resource>`. Compare with
  `kubectl describe node` (Capacity/Allocatable).
- **DRA**: a claim whose DeviceClass doesn't exist, or whose selectors match
  no free device, can't be allocated.
- **Kueue**: a wrong `kueue.x-k8s.io/queue-name`, a missing LocalQueue, or
  not enough quota keeps the Job suspended. The Workload's conditions say why.
- **ResourceQuota**: besides "exceeded quota", a quota on `requests.cpu` or
  `requests.memory` *requires* every pod in the namespace to set those
  requests, or it is rejected.

## The situation

Four GPU nodes, all tainted `nvidia.com/gpu=present:NoSchedule`: `h100-1`
(8×H100), `l4-1` (8×L4), `mig-1` (2×A100 partitioned into 14 × `1g.10gb`
MIG slices) and `dra-1` (2×L40S published via DRA, DeviceClass
`gpu.nvidia.com`). Namespace `research` has a ResourceQuota `compute` and a
Kueue LocalQueue `research-queue` (ClusterQueue `research-cq`, 4 L4 GPUs).

Six workloads, none of them running:
- `prod`: `chat` (2 × 1 L4), `llm` (8 H100), `embed` (3 × MIG 1g.10gb),
  `vision` (1 L40S via the DRA template `l40s-gpu`)
- `research`: `sweep` (Kueue Job, 2 × 1 L4), `notebook` (1 L4)

## Your task

Get all six running, each on its intended GPU type:

- `chat`: 2 ready, on the L4 node · `llm`: ready on the H100 node with 8 GPUs ·
  `embed`: 3 ready, each with one `nvidia.com/mig-1g.10gb` ·
  `vision`: Running with an L40S allocated through DRA (still via template
  `l40s-gpu`, no `nvidia.com/gpu`)
- `sweep`: labelled for `research-queue`, admitted, both pods Running ·
  `notebook`: 1 ready on the L4 node

Rules: keep the replica counts and GPU amounts. Don't change nodes, taints,
ResourceSlices, the DeviceClass, Kueue flavors/queues, or the ResourceQuota.
Fix the workloads.

## Useful commands

    kubectl get pods,jobs,workloads -n prod -o wide;  kubectl get pods,jobs,workloads -n research -o wide
    kubectl -n prod describe pod -l app=chat
    kubectl get events -A --field-selector reason=FailedScheduling
    kubectl -n research describe rs -l app=notebook
    kubectl -n research describe workload
    kubectl get nodes -L nvidia.com/gpu.product
    kubectl describe node mig-1 | grep -A8 Allocatable
    kubectl get deviceclass; kubectl -n prod get resourceclaims -o yaml

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/concepts/policy/resource-quotas/#requests-vs-limits
- https://kueue.sigs.k8s.io/docs/tasks/troubleshooting/troubleshooting_jobs/
- https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/
