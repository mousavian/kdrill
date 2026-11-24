# Solution

From the lesson directory:

    kubectl -n prod delete resourceclaimtemplate l40s-gpu
    kubectl apply -f solution/prod.yaml -f solution/research.yaml
    kubectl -n prod rollout restart deploy vision

| Workload | Evidence | Cause | Fix |
|---|---|---|---|
| chat | `untolerated taint {nvidia.com/gpu: present}` on l4-1 | no toleration | add `tolerations: [{key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}]` |
| llm | `didn't match Pod's node affinity/selector` everywhere | `NVIDIA-H100-80GB` isn't a real GFD value | `NVIDIA-H100-80GB-HBM3` |
| embed | `Insufficient nvidia.com/mig-1g.5gb` | 1g.5gb is an A100-40GB profile; mig-1 offers `1g.10gb` | `nvidia.com/mig-1g.10gb: 1` |
| vision | pod Pending, its claim unallocated; events say DeviceClass `nvidia-gpu` not found | template names a DeviceClass that doesn't exist | re-create template with `gpu.nvidia.com` (immutable → delete first), restart the pod so it gets a new claim |
| sweep | Job suspended, Workload inadmissible: LocalQueue `research` doesn't exist | wrong `kueue.x-k8s.io/queue-name` | `research-queue` (the label can change while the Job is still suspended) |
| notebook | no pod; ReplicaSet `FailedCreate ... must specify requests.cpu, requests.memory` | quota `compute` covers cpu/memory, so every pod must request them | add `requests: {cpu: "2", memory: 8Gi}` |

Takeaways:
- Pending pod → scheduler events. Missing pod → controller events. Suspended
  Job → Workload conditions. DRA → the ResourceClaim.
- Read `0/N nodes are available` node by node; the node you expected to work
  tells you what is wrong.
- Fix workloads, not shared infrastructure: relabelling nodes, deleting taints
  or loosening quotas makes the next incident worse.
