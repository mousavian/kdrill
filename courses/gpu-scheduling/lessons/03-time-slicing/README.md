# Share GPUs with time-slicing (and know its limits)

## Concept

A GPU is a large, expensive device, and many workloads leave it mostly idle: a
Jupyter notebook, a dev pod, a small model serving a few requests a minute.
The NVIDIA device plugin can **time-slice** a GPU: with a config like

    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 4

each physical GPU is advertised as 4 `nvidia.com/gpu` units. A node with 4
T4s then shows `nvidia.com/gpu: 16`, and 16 pods can each "have a GPU". The
GPU switches between their CUDA contexts in turns.

GPU Feature Discovery labels such nodes so you can tell:

- `nvidia.com/gpu.replicas=4` and `nvidia.com/gpu.count=4` (physical)
- `nvidia.com/gpu.sharing-strategy=time-slicing` (`none` on normal nodes,
  `mps` for MPS sharing)
- `nvidia.com/gpu.product=Tesla-T4-SHARED` (the default `-SHARED` suffix)

What you give up:

- **No memory isolation.** All pods on a GPU share its memory; one greedy pod
  can make the others fail with out-of-memory errors.
- **No performance isolation.** Each pod gets a share of time, not a share of
  compute, and context switching adds overhead.
- **Requests lose their meaning.** The scheduler counts replicas, not cards. A
  pod asking for `nvidia.com/gpu: 4` on a shared node may get 4 slices of the
  *same* physical GPU, and the plugin doesn't fail the request.

So time-slicing is a good fit for many small, bursty, trusted workloads, and a
bad fit for multi-GPU training or anything latency-sensitive. Keep the two
apart with node affinity on the sharing labels.

## The situation

`t4-shared-1` has 4 physical T4s, time-sliced ×4 (16 advertised). `a10g-1` and
`a10g-2` have 4 exclusive A10Gs each. Eight `notebooks` (1 GPU each) spread
over all three nodes, and the 4-GPU `trainer` ended up on the shared node.

## Your task

- All 8 `notebooks` pods Running on time-sliced nodes, enforced by a required
  rule (nodeSelector or required node affinity) on
  `nvidia.com/gpu.sharing-strategy`.
- `trainer` Running on exclusive GPUs (`nvidia.com/gpu.sharing-strategy=none`),
  enforced by a required rule on the same label.

Rules:
- Keep the replicas (8 and 1) and the GPU requests (1 and 4 per pod).
- Don't change the nodes or add any.

## Useful commands

    kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.count,nvidia.com/gpu.replicas,nvidia.com/gpu.sharing-strategy
    kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
    kubectl get pods -o wide

When you think you're done: `kdrill verify`

## On a real cluster

The sharing is configured on the device plugin (via the GPU Operator's
ClusterPolicy and a ConfigMap, optionally per node with the
`nvidia.com/device-plugin.config` label). GFD then relabels the node. Here the
labels and the inflated capacity are set directly on the fake node; the
scheduler behaviour is the same.

## Read more

- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html
- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
