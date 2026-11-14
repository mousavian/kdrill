Where do the pods run now, and what do the GPU nodes look like?
`kubectl get pods -o wide`; `kubectl describe node gpu-1` (see Taints,
Capacity and Allocatable for `nvidia.com/gpu`).
---
Two separate things are needed. (1) The pod must *ask* for GPUs, which is what
makes the scheduler look for nodes with `nvidia.com/gpu` capacity. (2) The GPU
nodes are tainted, so the pod must *tolerate* that taint. Extended resources
go in `resources.limits` as whole integers.
---
    kubectl patch deploy llm -p '{"spec":{"template":{"spec":{
      "tolerations":[{"key":"nvidia.com/gpu","operator":"Exists","effect":"NoSchedule"}],
      "containers":[{"name":"server","resources":{"limits":{"nvidia.com/gpu":"2"}}}]}}}}'

or edit the Deployment / `kubectl apply -f solution/llm.yaml`.
