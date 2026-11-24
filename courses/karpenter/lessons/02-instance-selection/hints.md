Read Karpenter's side of the story:

    kubectl -n apps describe pod -l app=worker | tail -5
    kubectl -n karpenter logs deploy/karpenter | tail -5

No instance type in this cloud matches `m5.*`. List what exists:
`kubectl -n karpenter get cm instance-types -o jsonpath='{.data.catalog\.txt}'`.
---
Replace the instance-type list with requirements that describe the shape:
`kubernetes.io/arch` In `[arm64]`, `karpenter.k8s.aws/instance-category`
In `[m]`, and `karpenter.kwok.sh/instance-cpu` `Gt` `["3"]` (values are
strings, even for Gt). Keep the capacity-type requirement.
---
    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

All 7 pods (15 CPU, 30 GiB) fit on one `m7g.4xlarge` (16 vCPU, 64 GiB,
$0.65/h), cheaper than an `m7g.xlarge` for api plus an `m7g.4xlarge` for
worker ($0.82/h).
