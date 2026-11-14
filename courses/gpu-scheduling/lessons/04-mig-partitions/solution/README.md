# Solution

The MIG node advertises only `nvidia.com/mig-*` resources, so every pod asking
for `nvidia.com/gpu: 1` competed for `h100-1`'s 8 whole GPUs. A 3 GB embedding
model was holding a full 80 GB H100.

Ask for MIG slices instead (full files in this folder):

    kubectl apply -f solution/      # from the lesson directory

- `embed`: `limits: {nvidia.com/mig-1g.10gb: 1}` → 8 of the 16 1g.10gb slices.
- `rerank`: `limits: {nvidia.com/mig-2g.20gb: 1}` → 4 of the 8 2g.20gb slices.

Both move to `h100-mig-1` (the only node offering those resources). `h100-1`
empties and the Pending `pretrain` pod takes its 8 whole GPUs.

Takeaways:
- MIG gives hardware isolation (memory, compute, bandwidth); time-slicing
  doesn't.
- Pick the smallest profile that fits the model's memory plus headroom.
  Over-sizing wastes slices just as whole GPUs do.
- Partitions are fixed until an admin changes `nvidia.com/mig.config`, so the
  layout should follow the workload mix. Unused profile types are wasted
  capacity (here the 8 × 3g.40gb slices sit idle).
