# Solution

From the lesson directory:

    kubectl apply -f solution/llm-8b.yaml

`llm-8b` gets `replicas: 4` and `nodeSelector: {kubernetes.io/hostname: a100-2}`.

Why it was stuck: demand was 6 x 1 + 4 = 10 GPUs on an 8-GPU fleet, and, worse, the default scheduler
**spreads** pods, so the six 8B replicas landed 3 + 3 and each node kept 1 GPU free: 2 free GPUs, but never 4 on the same node. A
tensor-parallel replica needs all its GPUs on one node (they talk over NVLink), so the 70B pod stayed Pending
with `Insufficient nvidia.com/gpu`. This is **GPU fragmentation**, the same as bin-packing
trouble anywhere, but each unit is expensive.

The fix has two parts: reduce the demand to what fits (4 small replicas + the 70B = 8 GPUs), and keep the small
replicas packed on one node so the big one has an empty node. In production you would not pin to a host name: use a **node
pool** per model size (labels such as `gpu.example.com/pool: large-models`), a bin-packing scheduler profile
(MostAllocated; see the gpu-scheduling course, lesson 02) for the small models, and a cluster
autoscaler that can add whole GPU nodes.

Pending is information: `kubectl describe pod` names the reason per node, and
`kubectl get nodes -o custom-columns=...` shows what is allocatable. Always read both before changing anything.
