Compare what each node advertises with what it physically has:

    kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.count,nvidia.com/gpu.replicas,nvidia.com/gpu.sharing-strategy
    kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

`t4-shared-1` has 4 physical GPUs but advertises 16. Where did `trainer` land?
---
The scheduler sees 16 interchangeable `nvidia.com/gpu` on `t4-shared-1`; it
cannot tell that 4 of them may be the same physical card. Only the labels say
so. Both workloads need a hard rule on `nvidia.com/gpu.sharing-strategy`:
notebooks `= time-slicing`, trainer must avoid `time-slicing`.
---
    kubectl patch deploy notebooks --type merge -p \
      '{"spec":{"template":{"spec":{"nodeSelector":{"nvidia.com/gpu.sharing-strategy":"time-slicing"}}}}}'
    kubectl patch deploy trainer --type merge -p \
      '{"spec":{"template":{"spec":{"nodeSelector":{"nvidia.com/gpu.sharing-strategy":"none"}}}}}'

Both use `Recreate`. If `trainer` is Pending for a moment, it is waiting for
the notebooks to leave the A10G nodes.
