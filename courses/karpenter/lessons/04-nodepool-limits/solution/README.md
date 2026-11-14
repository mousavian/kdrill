# Solution

    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

    limits:
      cpu: "16"
      memory: 64Gi
      nvidia.com/gpu: "0"

- `web`: Karpenter has 12 CPUs of headroom, launches a second 4-vCPU node
  for the 3 waiting pods, and `status.resources.cpu` becomes 8.
- `ml-batch`: every instance type with a GPU now exceeds `nvidia.com/gpu: 0`,
  so its event says `all available instance types exceed limits for
  nodepool`. It stays Pending until someone gives it a pool with a GPU
  budget (lesson 6).

The trap: with only `cpu: "16"` the pool would launch a `g6.2xlarge`
($0.98/h) for the GPU pod, and Karpenter would pack the waiting `web` pods
onto it as well. Limits don't evict anything, so you'd have to delete that
NodeClaim yourself.
