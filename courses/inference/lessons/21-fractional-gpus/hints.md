    kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,MIG10:.status.allocatable.nvidia\.com/mig-1g\.10gb,MIG5:.status.allocatable.nvidia\.com/mig-1g\.5gb'
    kubectl describe pod -l app=embed | tail -6

The partitioned nodes advertise slices as their own resources. The model needs about 9 GB (see the annotation): which
slice size is the smallest that holds it?
---
In the `embed` container: `limits: {nvidia.com/mig-1g.10gb: 1}` instead of `nvidia.com/gpu: 1`
(requests default to the limits for extended resources). Seven slices on `mig-80` hold six replicas.
---
    kubectl apply -f solution/embed.yaml      # from the lesson directory
