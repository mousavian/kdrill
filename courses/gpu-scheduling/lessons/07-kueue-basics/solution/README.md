# Solution

    kubectl apply -f solution/kueue.yaml      # from the lesson directory

It creates:

- ResourceFlavor `a100` with `nodeLabels: {nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB}`,
- ClusterQueue `ml-cq` with `namespaceSelector: {}`, covering cpu/memory/GPU,
  `nvidia.com/gpu` quota 8,
- LocalQueue `ml-team` → `ml-cq`.

Kueue finds the three Workloads in the LocalQueue, admits `train-1` and
`train-2` (4 + 4 GPUs = the quota), injects
`nodeSelector: nvidia.com/gpu.product=NVIDIA-A100-SXM4-80GB` into their pod
templates, and unsuspends them. `train-3` stays suspended, with no pods and a
Workload that says `insufficient unused quota for nvidia.com/gpu`. When one of
the running jobs finishes (6 simulated hours here), train-3 is admitted.

Pitfalls:
- `namespaceSelector` omitted = no namespace may use the ClusterQueue.
- A resource the pods request but the ClusterQueue doesn't cover (e.g.
  forgetting `memory`) makes the Workload inadmissible.
- The flavor's `nodeLabels` is what keeps the jobs off the T4 node.
