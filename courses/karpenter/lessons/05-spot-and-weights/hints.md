Start from the existing pool: `kubectl get nodepool on-demand -o yaml`. The
spot pool is the same with `karpenter.sh/capacity-type` In `[spot]`, a
`spec.weight` (1-100) and `spec.limits.cpu: "16"`. Karpenter tries pools by
descending weight.
---
`api` must not follow the cheaper pool: a `nodeSelector` of
`karpenter.sh/capacity-type: on-demand` keeps it on on-demand nodes even
after consolidation or a rollout. Then `kubectl -n batch scale deploy render --replicas=10`.
---
    kubectl apply -f solution/spot-nodepool.yaml -f solution/api.yaml   # from the lesson directory
    kubectl -n batch scale deploy render --replicas=10

Spot takes 7 render pods on one 16-vCPU node (its whole budget); the other 3
overflow to the on-demand pool.
