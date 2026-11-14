# Solution

    kubectl apply -f solution/prod.yaml -f solution/ml.yaml -f solution/batch.yaml   # from the lesson directory

| Workload | Evidence | Cause | Fix |
|---|---|---|---|
| checkout | Pending; karpenter's `FailedScheduling` gives one reason per pool: two `did not tolerate taint`, and for `general` `no instance type met the scheduling requirements ...` with `topology.kubernetes.io/zone In [us-east-1a]` in the list | zone from another region | drop the zone pin (or use us-west-2a/b/c) |
| legacy | the general NodeClaim stays `Drifted=True`; events `DisruptionBlocked: Pod has "karpenter.sh/do-not-disrupt" annotation (Pod=prod/legacy-...)` | stale do-not-disrupt in the pod template | remove it from the template (the rollout replaces the pod, then drift proceeds) |
| embed | Pending; karpenter: `did not tolerate taint (taint=nvidia.com/gpu=true:NoSchedule)` for the GPU pool, `no instance type had enough resources` (no GPUs) for `general` | no toleration for the GPU pool's taint | add the toleration |
| rerank | Running alone on a `p4d.24xlarge`: 7 idle GPUs | pinned to `a100`; the only A100 type has 8 GPUs | `instance-gpu-name In [l4, a10g]` + `instance-gpu-count: "1"` |
| crunch | 3 Running, 3 Pending; karpenter: `all available instance types exceed limits for nodepool (NodePool=spot)` and, for `general`, `incompatible requirements, key karpenter.sh/capacity-type` | `nodeSelector capacity-type: spot` forbids the on-demand fallback | remove the selector; spot (weight 50) is still tried first whenever it has budget |

embed and rerank also get `instance-gpu-count: "1"`: once both are fixed they
are pending at the same time, and Karpenter would otherwise pack them onto one
4-GPU `g6.12xlarge` with 2 GPUs idle.

Takeaways:
- Pod Pending → read the event **from karpenter** (`kubectl describe pod`): it
  names the NodePool problem (no instance type, taint, limits).
- Fleet change not rolling out → `kubectl get nodeclaims` + node events
  (`DisruptionBlocked`): do-not-disrupt, PDBs, budgets.
- Expensive node → `kubectl get nodes -L node.kubernetes.io/instance-type,eks-node-viewer/instance-price`
  and compare requests with capacity.
