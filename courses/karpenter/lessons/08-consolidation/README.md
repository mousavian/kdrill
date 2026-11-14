# Consolidation shrinks the fleet after scale-down

## Concept

Provisioning is half of Karpenter's job; the other half is taking nodes
away. **Consolidation** keeps looking for a cheaper way to run the pods you
have:

- **Delete**: a node whose pods all fit on the other nodes' free capacity is
  drained and removed.
- **Replace**: a node whose pods would fit on one *cheaper* node is replaced
  (the new node is launched first, then the old one drained).
- It also considers several nodes at once ("these three nodes' pods fit on
  one new node").
- It re-evaluates when the cluster changes, and otherwise every few minutes:
  a fleet can sit one step short of optimal for ~5 minutes after the last
  change.

`spec.disruption` on the NodePool controls it:

- `consolidationPolicy: WhenEmpty` only removes nodes with no pods
  (DaemonSet pods don't count). Safe, but a node with one tiny pod left keeps
  running forever.
- `WhenEmptyOrUnderutilized` (the default) also deletes or replaces nodes
  that are merely underutilized. (Karpenter 1.15 adds `Balanced`, which only
  makes moves whose savings justify the disruption.)
- `consolidateAfter`: how long a node must have had no pod scheduled to it or
  removed from it before it's considered (`0s`, `30s`, `5m`, `Never`). Short
  values react fast but churn pods; minutes are common in production.

Draining uses evictions: pods are recreated elsewhere by their controllers,
and PodDisruptionBudgets and `karpenter.sh/do-not-disrupt` are respected
(next lesson). Karpenter emits events as it works:
`ConsolidationCandidate`, `DisruptionLaunching`,
`DisruptionTerminating ... Underutilized` (or `Empty`), `Evicted`, and
`Unconsolidatable` with the reason when it decides not to.

## The situation

NodePool `default` (amd64, on-demand, c/m/r) has `consolidationPolicy:
WhenEmpty` and `consolidateAfter: 10m`. A traffic peak brought 12 `web`
and 3 `worker` pods (1 CPU each) to namespace `shop` at once, and Karpenter
launched one 16-vCPU node for them. They've since scaled down to `web` 2 and
`worker` 1, but the big node is still there: it isn't empty.

## Your task

Make NodePool `default` consolidate underutilized nodes:
`consolidationPolicy: WhenEmptyOrUnderutilized` with `consolidateAfter` of
**30s or less**.

Result: `web` (2) and `worker` (1) Running, and the fleet shrinks to **at
most 4 vCPUs** because Karpenter consolidated it (verify looks for its
`DisruptionTerminating ... Underutilized` events).

Rules: don't scale or change the workloads; don't delete nodes or
NodeClaims yourself; don't create nodes. Expect ~30-90 s after the change.

## Useful commands

    kubectl get nodeclaims -w
    kubectl get nodes -L node.kubernetes.io/instance-type
    kubectl describe node <name> | grep -A6 'Allocated resources'
    kubectl get events -A --sort-by=.lastTimestamp | grep -E 'Consolidat|Disruption|Evicted'
    kubectl -n karpenter logs deploy/karpenter | grep -i disrupt

When you think you're done: `kdrill verify`

## On a real cluster

Same algorithm. Replacements on AWS take as long as a launch (tens of
seconds to minutes) and pods restart for real, so `consolidateAfter` is
usually minutes. Consolidation compares *prices*: it only replaces a node
with a cheaper one, and spot-to-spot replacement additionally needs at least
15 cheaper instance types to choose from. Preferences (preferred affinity,
`ScheduleAnyway` spreads) are honoured when Karpenter simulates where pods
would go, so they can stop a consolidation.

## Read more

- https://karpenter.sh/docs/concepts/disruption/#consolidation
- https://karpenter.sh/docs/concepts/nodepools/#specdisruption
