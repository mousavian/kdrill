# Solution

    kubectl patch nodepool default --type merge \
      -p '{"spec":{"disruption":{"consolidationPolicy":"WhenEmptyOrUnderutilized","consolidateAfter":"15s"}}}'

(or `kubectl apply -f solution/nodepool.yaml`).

Before: a `c6i.4xlarge` (bought for the 15 peak pods) now runs 3 pods worth
3 CPUs. With `WhenEmpty` Karpenter can only remove a node with no pods.

After: once the node has been stable for 15 s, Karpenter finds that its
three pods fit on one cheaper `c6i.xlarge` (3.9 allocatable vCPUs). Events:
`ConsolidationCandidate ... replace`, `DisruptionLaunching` (the new node
comes up first), then `DisruptionTerminating ... Underutilized` and
`Evicted` for each pod on the old node:

    kubectl get events -A --field-selector reason=DisruptionTerminating
    ... nodeclaim/default-abcde   Disrupting NodeClaim: Underutilized

From 16 vCPUs ($0.68/h) to 4 vCPUs ($0.17/h).

Notes:
- Replacement is launch-before-drain, so capacity is never lower than needed.
- Consolidation can't *split* a node: it deletes or replaces nodes with
  fewer/cheaper ones. A pod that "just fits" on a big node stays there unless
  a cheaper single node also fits.
