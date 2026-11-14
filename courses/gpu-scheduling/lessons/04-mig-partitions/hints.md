Look at what each node offers and who uses it:

    kubectl describe node h100-mig-1 | grep -E 'nvidia.com/(gpu|mig)'
    kubectl describe node h100-1 | grep -A12 'Allocated resources'

`h100-mig-1` advertises no `nvidia.com/gpu` at all, only `nvidia.com/mig-*`
resources. Every inference pod asks for a whole `nvidia.com/gpu`, so they all
compete for `h100-1`'s 8 GPUs.
---
With the MIG **mixed** strategy each slice size is its own extended resource,
named after the profile: `<compute slices>g.<memory>gb`. Pick the smallest
that fits each model: embed needs ~3 GB, rerank ~15 GB. Pods ask for MIG
slices in `limits` exactly like GPUs.
---
In each Deployment replace `nvidia.com/gpu: 1` with the MIG resource:

- embed:  `limits: {nvidia.com/mig-1g.10gb: 1}`
- rerank: `limits: {nvidia.com/mig-2g.20gb: 1}`

`kubectl apply -f solution/` from the lesson directory does both. The pods
move to `h100-mig-1`, `h100-1` empties, and `pretrain` gets its 8 GPUs.
