# Solution

    kubectl apply -f solution/apps.yaml      # from the lesson directory

| Workload | Problem | Fix |
|---|---|---|
| chat | `nvidia.com/gpu.product` is a runtime (GFD) label; Karpenter: no instance type has it | `karpenter.k8s.aws/instance-gpu-name: l4` |
| chat | 3 pods pending together get packed onto one 4-GPU `g6.12xlarge` (1 idle GPU, $4.60/h) | `karpenter.k8s.aws/instance-gpu-count: "1"`: three `g6.xlarge` ($0.81/h each) |
| eval | `a100` exists only as `p4d.24xlarge`: 8 GPUs, 7 idle, ~$22/h | `instance-gpu-name In [l4, a10g]` + `instance-gpu-count In ["1"]`: a `g6.xlarge` |

End state: 3 × `g6.xlarge` (chat), 1 × `g6.xlarge` (eval), 1 × `p5.48xlarge`
(train): 0 idle GPUs, $58.26/h, down from about $77/h of which ~$19/h was
idle GPUs. Consolidation removes the empty `p4d.24xlarge` ~15 s after `eval`
leaves it.

Takeaways:
- Select GPUs by capability with provider labels (`instance-gpu-name`,
  `-memory`, `-count`), never with runtime labels from GPU feature discovery.
- Karpenter minimises the price of each new node, not of your fleet over
  time: it packs whatever is pending together. Pin the instance *size* for
  1-GPU workloads (or give them their own NodePool).
- `kubectl get nodes -L eks-node-viewer/instance-price` (or the
  eks-node-viewer tool) makes the bill visible.
