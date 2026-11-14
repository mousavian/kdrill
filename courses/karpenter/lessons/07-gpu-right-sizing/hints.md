`chat`: `kubectl -n ai describe pod -l app=chat | tail -3`. Karpenter can't
find an instance type with label `nvidia.com/gpu.product`: that label is
added by software on a node *after* it boots. Which GPU labels do instance
types carry? `kubectl get nodes --show-labels | tr , '\n' | grep gpu`.
---
`eval` is on an 8-GPU `p4d.24xlarge` because `a100` only comes in that size.
The model needs 24 GB: `l4` and `a10g` qualify (`In [l4, a10g]` in a node
affinity). Once `chat` runs, check idle GPUs: Karpenter packed the pods that
were pending together onto one multi-GPU node. Require
`karpenter.k8s.aws/instance-gpu-count: "1"` for 1-GPU pods.
---
    kubectl apply -f solution/apps.yaml      # from the lesson directory

`chat`: nodeSelector `instance-gpu-name: l4` + `instance-gpu-count: "1"`.
`eval`: affinity `instance-gpu-name In [l4, a10g]`, `instance-gpu-count In ["1"]`.
The emptied `p4d.24xlarge` is consolidated away.
