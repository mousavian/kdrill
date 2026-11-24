# Why is my pod Pending?

## Concept

The scheduler places a pod by looking at its **requests**, not at what it
actually uses. For each node it does simple arithmetic:

    node allocatable  −  sum of requests of pods already on the node  ≥  this pod's requests ?

If no node passes that test, the pod stays `Pending` and the scheduler records
a `FailedScheduling` event explaining why, e.g.

    0/3 nodes are available: 1 node(s) had untolerated taint ..., 2 Insufficient cpu.

Things worth knowing:

- **Requests** reserve capacity and drive scheduling. **Limits** cap usage at
  runtime and play no part in placement.
- A node's **allocatable** is what pods can reserve. `kubectl describe node`
  shows it, plus an "Allocated resources" table with the running total.
- Requests are per pod and cannot be split across nodes: 2 free CPUs on node A
  plus 2 free on node B does not fit one pod asking for 3.
- The control-plane node in this cluster is tainted, so your pods cannot land
  there — just like in a real cluster.

## The situation

A colleague deployed `web` with 3 replicas. Two came up, one is stuck Pending.
The cluster has two worker nodes, `node-a` and `node-b`, and there is no budget
for more.

## Your task

Get all 3 replicas Running.

Rules:
- Keep 3 replicas.
- Keep the two nodes as they are — no new nodes, no editing node capacity.
- Each pod must still request at least 1 CPU (the app genuinely needs that).

## Useful commands

    kubectl get pods -o wide
    kubectl describe pod <pending-pod>      # read Events
    kubectl describe node node-a            # Allocatable + Allocated resources
    kubectl get events --sort-by=.lastTimestamp
    kubectl edit deploy web                 # or: kubectl set resources ...

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/
