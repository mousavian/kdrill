# Queue GPU jobs with Kueue

## Concept

The scheduler places *pods*. If you submit more GPU jobs than fit, their pods
sit Pending, some jobs start half their workers, and quotas can only reject.
**Kueue** adds a layer before scheduling: it decides which *jobs* may start,
based on quota, and holds the others in a queue.

The objects:

- **ResourceFlavor** (cluster-scoped): a kind of capacity, usually a node
  type. Its `spec.nodeLabels` are added as a nodeSelector to the pods Kueue
  admits under it, e.g. `nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB`.
- **ClusterQueue** (cluster-scoped): the quota. `resourceGroups` list the
  `coveredResources` (every resource the pods request: cpu, memory and
  `nvidia.com/gpu`) and a `nominalQuota` per flavor. `namespaceSelector`
  says which namespaces may use it: `{}` means all, and leaving it out
  (null) means **none**.
- **LocalQueue** (namespaced): what users submit to. It points to a
  ClusterQueue. A Job opts in with the label
  `kueue.x-k8s.io/queue-name: <localqueue>`.

What happens to a Job:

1. Kueue's webhook creates it **suspended** (`spec.suspend: true`), so the
   Job controller creates no pods.
2. Kueue creates a **Workload** for it: the total requests of all its pods.
3. When the ClusterQueue has enough unused quota for the *whole* Workload,
   Kueue **admits** it: it picks a flavor, injects the flavor's node labels and
   unsuspends the Job. The pods are created and scheduled as usual.
4. Otherwise the Workload waits in the queue (FIFO by default). When an
   admitted job finishes, its quota is released and the next one starts.

Quota is not capacity: Kueue counts what it has admitted against
`nominalQuota` and doesn't look at free GPUs on nodes. Set quotas that the
nodes can actually provide.

## The situation

Kueue is installed (namespace `kueue-system`). The fleet has two 8×A100 nodes
and a 4×T4 node. In namespace `ml-team`, three Jobs (`train-1..3`, each 2 pods
× 2 GPUs = 4 GPUs) are labelled for queue `ml-team`, but no queue exists yet,
so they are suspended and nothing runs. The team's budget is 8 A100 GPUs.

## Your task

- ResourceFlavor `a100` with `nodeLabels`
  `nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB`.
- ClusterQueue `ml-cq` (no cohort) covering `cpu`, `memory` and
  `nvidia.com/gpu` in flavor `a100`, with a quota of exactly **8**
  `nvidia.com/gpu` (use 64 CPUs and 512Gi memory so those are not the limit).
- LocalQueue `ml-team` in namespace `ml-team` pointing to `ml-cq`.

Result: exactly 2 Jobs admitted with both pods Running on A100 nodes, 1 Job
still queued (suspended, no pods).

Rules: don't delete or change the Jobs (they keep 2 pods × 2 GPUs); don't
change the nodes.

## Useful commands

    kubectl get jobs,workloads
    kubectl describe workload <name>              # why it is not admitted
    kubectl get clusterqueue,localqueue,resourceflavor
    kubectl describe clusterqueue ml-cq           # usage vs quota
    kubectl explain clusterqueue.spec --api-version=kueue.x-k8s.io/v1beta2
    kubectl get pods -o wide

When you think you're done: `kdrill verify`

## On a real cluster

Job pods here run on KWOK nodes, and the simulation keeps them "running" for 6
hours (the `pod-complete.stage.kwok.x-k8s.io/delay` annotation, which means
nothing on a real cluster). Everything Kueue does here (suspension, Workloads,
admission, flavor node labels) is the real controller at work.

## Read more

- https://kueue.sigs.k8s.io/docs/overview/
- https://kueue.sigs.k8s.io/docs/concepts/cluster_queue/
- https://kueue.sigs.k8s.io/docs/concepts/resource_flavor/
- https://kueue.sigs.k8s.io/docs/tasks/run/jobs/
