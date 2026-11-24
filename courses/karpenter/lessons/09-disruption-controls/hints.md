Order matters: once consolidation is on, Karpenter starts evicting within
seconds. Annotate the ledger pod first:
`kubectl -n pay annotate pod -l app=ledger karpenter.sh/do-not-disrupt=true`.
Editing the Deployment instead would recreate the pod (and restart the
20-minute replay).
---
PDB: `policy/v1` PodDisruptionBudget, `selector.matchLabels: {app: api}`,
`maxUnavailable: 1`. Budgets: `kubectl explain nodepool.spec.disruption.budgets`.
A schedule needs a duration, and both are only allowed together.
---
From the lesson directory:

    kubectl -n pay annotate pod -l app=ledger karpenter.sh/do-not-disrupt=true
    kubectl apply -f solution/pdb.yaml
    kubectl apply -f solution/nodepool.yaml
