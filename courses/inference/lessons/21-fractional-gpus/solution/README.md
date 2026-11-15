# Solution

From the lesson directory:

    kubectl apply -f solution/embed.yaml

`embed` requests `nvidia.com/mig-1g.10gb: 1` instead of `nvidia.com/gpu: 1`.

**MIG** (Multi-Instance GPU, A100/H100 and later) cuts one GPU into up to seven hardware-isolated
instances, each with its own memory and compute slices; a profile name `1g.10gb` means one
compute slice and 10 GB. With the "mixed" strategy the device plugin advertises each profile as a separate
resource (`nvidia.com/mig-1g.10gb`), so a pod asks for exactly the size it needs. The scheduler places six
pods on `mig-80`'s seven slices: one GPU's worth of hardware serves six replicas that would
have needed six GPUs, with memory isolation between them (a crash or leak in one cannot take
the others down).

The smallest slice that fits matters: the 5 GB profile would have scheduled just as easily on `mig-40`, and the
model (9 GB) would have died with an out-of-memory error at load. A scheduler counts slices, not
gigabytes you meant.

The other sharing mechanisms: **time-slicing** (device plugin advertises one GPU as N
`nvidia.com/gpu`; pods take turns, no memory isolation, no guarantee: fine for dev and bursty
light load), **MPS** (concurrent execution with soft memory limits) and, on the pod
level, running several models in one server process (vLLM serves one model per process; Triton
and the llm-d "model per pod" pattern differ). Use MIG for predictable small models, whole GPUs for large ones.
