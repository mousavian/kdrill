# Disruption controls before you turn consolidation on

## Concept

Every voluntary disruption (consolidation, drift, expiry) ends with pods
being evicted. Three controls decide what Karpenter may take, and when:

**Pod level: `karpenter.sh/do-not-disrupt: "true"`.** A pod with this
annotation makes its node off limits for voluntary disruption: Karpenter
won't pick the node for consolidation or drift replacement while the pod
runs. Use it for things that must not move right now: a long batch step, a
singleton that replays for 20 minutes on restart. It's a pod annotation, so
you can set it on a running pod without restarting it. A duration value
(`"30m"`) protects the pod only for its first 30 minutes. If its node is
deleted anyway (expiry, `kubectl delete node`), the drain skips the pod and
waits, until the NodePool's `terminationGracePeriod` runs out (next lesson).

**Workload level: PodDisruptionBudgets.** Karpenter drains through the
Eviction API, which honours PDBs. `maxUnavailable: 1` lets it move one replica
at a time; `maxUnavailable: 0` (or `minAvailable` equal to replicas) blocks
the drain completely, which is a common reason a node "won't consolidate".

**NodePool level: disruption budgets** (`spec.disruption.budgets`):

    budgets:
    - nodes: "20%"                    # at most 20 % of the pool's nodes at once
    - nodes: "0"                      # nothing during the Black Friday window...
      schedule: "0 0 28 11 *"         # cron, UTC
      duration: 96h
    - nodes: "1"
      reasons: [Underutilized]        # ...and only one node at a time for consolidation

`nodes` is a count or a percentage of the pool's nodes; `reasons` limits a
budget to `Underutilized`, `Empty`, `Drifted` (or `Unhealthy`); `schedule` +
`duration` make it time-bound. When several apply, the most restrictive
wins. The default is one budget of `nodes: "10%"`.

`consolidateAfter: Never` turns consolidation off without changing the
policy, handy while you put guard rails in place.

## The situation

NodePool `default` has consolidation paused (`consolidateAfter: Never`). In
namespace `pay`: `api` (3 × 1 CPU), `ledger` (1 replica, a singleton that
replays for 20 minutes after a restart, in us-west-2a), and an empty
`settlement` Deployment whose finished run left `api` alone on a 16-vCPU node.

## Your task

1. Protect the **running** `ledger` pod with `karpenter.sh/do-not-disrupt:
   "true"`. It must not restart: annotate the pod, not the Deployment's
   template.
2. Create a PodDisruptionBudget for `app: api` that allows **exactly one**
   api pod to be unavailable (`maxUnavailable: 1` or `minAvailable: 2`).
3. On NodePool `default`, add two disruption budgets:
   - `nodes: "1"` with no schedule and no reasons,
   - `nodes: "0"` for `reasons: [Drifted]`, `schedule: "0 9 * * mon-fri"`
     (or `1-5`), `duration: 8h`.
4. Switch consolidation on: `consolidateAfter` of 30s or less.

Result: Karpenter consolidates the oversized api node (verify looks for its
`DisruptionTerminating ... Underutilized` event); apart from the ledger's
node the fleet has at most 4 vCPUs; `api` keeps 3 Running pods; the ledger's
original pod is still running.

Rules: don't change the NodePool's template or limits; don't change the
Deployments (replicas, resources, template); don't delete nodes or create
any. Consolidation takes ~30-90 s after step 4.

## Useful commands

    kubectl -n pay get pods -o wide
    kubectl -n pay annotate pod <pod> karpenter.sh/do-not-disrupt=true
    kubectl explain nodepool.spec.disruption.budgets
    kubectl get events -A --sort-by=.lastTimestamp | grep -E 'Disruption|Evicted|Unconsolidatable'
    kubectl describe node <ledger node> | tail      # DisruptionBlocked events

When you think you're done: `kdrill verify`

## On a real cluster

Identical. Two practical notes: budget schedules are UTC (no time zones), and
a budget of `nodes: "0"` without reasons also blocks drift replacement of
nodes running outdated AMIs, so keep such windows short. Spot interruptions
are *involuntary*: neither do-not-disrupt nor budgets can stop the cloud
reclaiming an instance. This simulation has no interruptions.

## Read more

- https://karpenter.sh/docs/concepts/disruption/#controls
- https://karpenter.sh/docs/concepts/disruption/#nodepool-disruption-budgets
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/
