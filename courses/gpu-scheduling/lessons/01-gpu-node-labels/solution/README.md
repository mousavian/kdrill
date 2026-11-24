# Solution

`llm-serve` asked for `nvidia.com/gpu.product: H100`, but GFD writes the full
name `NVIDIA-H100-80GB-HBM3`, so no node matched. `whisper` and `etl` had no
rules at all, and the default scheduler (which only scores CPU and memory)
preferred the biggest node, the H100 box.

Give each Deployment a required node affinity (full files in this folder):

    kubectl apply -f solution/      # from the lesson directory

- `llm-serve`: `nvidia.com/gpu.memory Gt 70000`, nodeSelector removed. Only the
  81559 MiB H100 qualifies today, and an H200 (141 GB) would qualify tomorrow.
- `whisper`: `nvidia.com/gpu.family In [turing, ampere]` → T4 or A10G nodes.
- `etl`: `nvidia.com/gpu.present DoesNotExist` → the CPU node.

Moving `whisper` off the H100 also frees the 2 GPUs that `llm-serve`'s second
replica needs (2 × 4 = all 8).

Takeaways:
- The scheduler counts `nvidia.com/gpu`; *which* GPU is your job, via labels.
- Prefer capability labels (`gpu.memory`, `gpu.compute.major`, `gpu.family`)
  with `Gt`/`In` over exact product names.
- In production, taint GPU nodes (e.g. `nvidia.com/gpu=present:NoSchedule`) so
  CPU pods stay off without needing a rule in every Deployment.
