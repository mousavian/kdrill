# Solution

`t4-shared-1` has 4 physical T4s, but the device plugin's time-slicing config
(`replicas: 4`) makes it advertise `nvidia.com/gpu: 16`. GFD marks this with
`nvidia.com/gpu.replicas=4`, `nvidia.com/gpu.sharing-strategy=time-slicing`
and the `-SHARED` product suffix. The scheduler only sees 16 identical units,
so once the notebooks had spread over the A10G nodes, the only place with 4
free "GPUs" was the shared node, and `trainer` landed there. It might be
running on a single physical T4, sharing it with notebooks.

Fix both sides with hard rules (full files in this folder):

    kubectl apply -f solution/      # from the lesson directory

- `notebooks`: `nodeSelector: {nvidia.com/gpu.sharing-strategy: time-slicing}`.
  8 notebooks take 8 of the 16 slices.
- `trainer`: required affinity `nvidia.com/gpu.sharing-strategy In [none]`, so
  it only gets whole GPUs. With the notebooks gone from the A10G nodes, one of
  them has 4 free.

Takeaways:
- Time-slicing oversubscribes: N replicas per GPU means N pods take turns on
  the GPU. There is no memory isolation (one pod can OOM the others) and no
  fairness guarantee. Fine for notebooks, dev and light inference; wrong for
  training or latency-critical serving.
- A pod asking for `nvidia.com/gpu: 4` on a shared node is NOT guaranteed 4
  physical GPUs. Keep multi-GPU jobs off shared nodes with a label rule.
- MPS (`sharing-strategy=mps`) is the alternative to time-slicing: processes
  run concurrently and get a memory limit each. MIG (next lesson) gives real
  hardware isolation.
