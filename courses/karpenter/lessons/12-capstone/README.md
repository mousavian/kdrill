# Capstone: why won't Karpenter do what I want?

## Concept

When Karpenter "doesn't work", the cause is almost always visible in one of
four places:

| Symptom | Where to look | Typical causes |
|---|---|---|
| Pod `Pending`, no NodeClaim | `kubectl describe pod`: `FailedScheduling` **from karpenter** | requirements no instance type meets (zone, arch, label Karpenter doesn't know), untolerated NodePool taint, `exceed limits for nodepool` |
| NodeClaim exists, not Ready | `kubectl describe nodeclaim`, controller logs | NodeClass not ready, launch errors (on a real cloud: capacity, IAM, subnets) |
| Too expensive | `kubectl get nodes -L node.kubernetes.io/instance-type,eks-node-viewer/instance-price`, `kubectl describe node` (Allocated) | pods pinned to an instance type or GPU model that only comes big, pods packed onto a multi-GPU node |
| Fleet doesn't shrink or roll | `kubectl get nodeclaims` (Drifted), node/NodeClaim events: `DisruptionBlocked`, `Unconsolidatable` | `karpenter.sh/do-not-disrupt`, PDBs that allow no eviction, budgets, `consolidateAfter`, `WhenEmpty` |

Karpenter's `FailedScheduling` message names the reason and usually lists the
combined requirements it tried: read it to the end. The controller log
(`kubectl -n karpenter logs deploy/karpenter`) shows every decision:
`found provisionable pod(s)`, `computed new nodeclaim(s)`,
`disrupting node(s)`.

A rule of thumb for fixes: NodePools are shared infrastructure, so fix the
workload when the workload is wrong. Loosening a pool's limits or taints to
make one pod run usually breaks the next team.

## The situation

Three NodePools: `general` (on-demand c/m/r, 48 CPUs; its template label was
just changed to `cost-center: shop-v2`, so its existing nodes are drifted),
`spot` (weight 50, spot c/m/r, tainted `spot=true:NoSchedule`, 8 CPUs) and
`gpu` (g/p families, tainted `nvidia.com/gpu=true:NoSchedule`, 16 GPUs).

- `prod/checkout` (3 pods): Pending.
- `prod/legacy` (1 pod): Running, but its node was never replaced after the
  relabel.
- `ml/embed` (1 GPU, wants an L4): Pending.
- `ml/rerank` (1 GPU, needs 16 GB of GPU memory): Running on a very big node.
- `batch/crunch` (6 pods, interruptible, spot preferred but on-demand is
  fine): half of it Pending.

## Your task

- `checkout`: 3 Running (anywhere in the region).
- `legacy`: Running, and the relabel has rolled out: every general node has
  `cost-center=shop-v2`.
- `embed`: Running on an L4 in the `gpu` pool.
- `rerank`: Running on a 24 GB GPU (`l4` or `a10g`).
- No idle GPUs in the fleet.
- `crunch`: all 6 Running, still tolerating the spot pool's taint (so spot
  remains its first choice).

Rules: don't change the NodePools; keep every workload's replicas and
resource requests; don't create or delete nodes or NodeClaims yourself (the
migration that needed `legacy` protected is over, so it may restart).
After your fixes, allow ~1 minute for replacements and consolidation.

## Useful commands

    kubectl get pods -A -o wide | grep -E 'prod|ml|batch'
    kubectl -n prod describe pod -l app=checkout | tail -4
    kubectl get nodeclaims -o 'custom-columns=NAME:.metadata.name,POOL:.metadata.labels.karpenter\.sh/nodepool,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,DRIFTED:.status.conditions[?(@.type=="Drifted")].status'
    kubectl get events -A --field-selector reason=DisruptionBlocked
    kubectl get nodepools -o custom-columns=NAME:.metadata.name,WEIGHT:.spec.weight,CPU:.status.resources.cpu,LIMIT:.spec.limits
    kubectl get nodes -L karpenter.sh/nodepool,node.kubernetes.io/instance-type,karpenter.k8s.aws/instance-gpu-count,eks-node-viewer/instance-price
    kubectl -n karpenter logs deploy/karpenter --tail=30

When you think you're done: `kdrill verify`

## On a real cluster

The same four places, plus the cloud: launch failures (insufficient
capacity, quota, IAM, subnet IPs) show on the NodeClaim and in the logs, and
the `EC2NodeClass` status says whether its AMIs, subnets and security groups
resolved. The KWOK provider can't fail a launch, so those causes aren't part
of this exercise.

## Read more

- https://karpenter.sh/docs/troubleshooting/
- https://karpenter.sh/docs/concepts/disruption/
- https://karpenter.sh/docs/concepts/scheduling/
