# Solution

    kubectl apply -f solution/spot-nodepool.yaml -f solution/api.yaml   # from the lesson directory
    kubectl -n batch scale deploy render --replicas=10

- NodePool `spot`: `weight: 50`, `capacity-type In [spot]`, `limits.cpu: 16`.
- `api` gets `nodeSelector: {karpenter.sh/capacity-type: on-demand}`. Its pods
  are recreated and land on the on-demand pool.
- `render` (10 × 2 CPU): Karpenter tries `spot` first. A `c6i.4xlarge` spot
  node (16 vCPUs, 15.9 allocatable) takes 7 pods and uses the whole budget.
  The remaining 3 pods fit no spot instance type without exceeding the limit,
  so the next pool by weight, `on-demand`, launches a node for them.

      kubectl get nodeclaims
      NAME              TYPE          CAPACITY    ...
      spot-cpfjd        c6i.4xlarge   spot
      on-demand-rbjcm   c6i.2xlarge   on-demand
      on-demand-9wzrm   c6i.2xlarge   on-demand      <- api

Variations worth knowing:
- One pool with `capacity-type In [spot, on-demand]` lets Karpenter pick spot
  and fall back to on-demand only when spot is unavailable. Use weights and
  limits when you want a *budget* for one kind of capacity.
- Pods that must never run on spot need a selector or affinity; weights alone
  only decide where *new* capacity comes from.
