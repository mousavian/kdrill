# Solution

The pods run on the CPU nodes because they ask for no GPU and don't tolerate the
GPU nodes' taint. Two fixes, both required:

1. **Request the GPUs** — in `resources.limits`: `nvidia.com/gpu: 2`. The
   scheduler then only considers nodes whose allocatable `nvidia.com/gpu` has at
   least 2 unreserved. (On real clusters the NVIDIA device plugin advertises that
   number; here it is written into the fake nodes' status.)
2. **Tolerate the taint** `nvidia.com/gpu=present:NoSchedule` so pods may land on
   the GPU nodes.

Apply `solution/llm.yaml` from the lesson directory, or:

    kubectl patch deploy llm -p '{"spec":{"template":{"spec":{
      "tolerations":[{"key":"nvidia.com/gpu","operator":"Exists","effect":"NoSchedule"}],
      "containers":[{"name":"server","resources":{"limits":{"nvidia.com/gpu":"2"}}}]}}}}'

The arithmetic: 2 nodes × 4 GPUs = 8 GPUs; each pod takes 2, so at most 4 pods
fit, and 3 replicas use 6, leaving 2. Note pods can't span nodes: a node with 1
free GPU can't serve a pod that needs 2.

Bonus: `kubectl scale deploy llm --replicas=5`. Four pods fit (2 per node); the
fifth stays Pending with `Insufficient nvidia.com/gpu`. Check the accounting with
`kubectl describe node gpu-1` → "Allocated resources".

Takeaways:
- A toleration alone doesn't put pods on GPU nodes; the GPU request does, because
  only those nodes have the resource.
- The taint is what keeps ordinary pods from occupying GPU nodes.
- Models: use the node label `nvidia.com/gpu.product` with a nodeSelector or
  affinity when you need a specific GPU type.
