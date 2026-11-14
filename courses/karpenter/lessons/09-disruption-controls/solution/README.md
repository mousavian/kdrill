# Solution

From the lesson directory, in this order (guard rails first, then the switch):

    kubectl -n pay annotate pod -l app=ledger karpenter.sh/do-not-disrupt=true
    kubectl apply -f solution/pdb.yaml
    kubectl apply -f solution/nodepool.yaml

1. **do-not-disrupt on the running pod.** Karpenter won't voluntarily
   disrupt (consolidate, drift-replace) a node that runs a pod with
   `karpenter.sh/do-not-disrupt: "true"`. Annotating the *pod* protects it now
   without a restart; put it in the Deployment's pod template at the next
   planned rollout so future pods carry it too (changing the template now
   would restart the ledger, exactly what you're avoiding).
2. **PDB for api.** Karpenter drains with the Eviction API, which honours
   PodDisruptionBudgets: `maxUnavailable: 1` means one api pod at a time.
   (`maxUnavailable: 0` would block every drain of api's node: a classic
   "why won't it consolidate" cause.)
3. **NodePool budgets** (`spec.disruption.budgets`): `nodes: "1"` always;
   `nodes: "0"` for `reasons: [Drifted]` from 09:00 UTC on weekdays for 8 h.
   When several budgets apply, the most restrictive wins. Then
   `consolidateAfter: 15s` switches consolidation on.

What Karpenter does next: the node that held the settlement run now carries
only the 3 api pods (3 of 16 vCPUs), so it's replaced by a 4-vCPU node: launch
first, then drain one api pod at a time. The ledger's node is left alone
(`kubectl describe node <ledger node>`: event
`Pod has "karpenter.sh/do-not-disrupt" annotation` whenever it's a candidate).

Budget fields, for reference: `nodes` is a count or percentage of the pool's
nodes; `reasons` is any of `Underutilized`, `Empty`, `Drifted` (and
`Unhealthy` for node repair); `schedule` is cron syntax in UTC and requires
`duration`.
