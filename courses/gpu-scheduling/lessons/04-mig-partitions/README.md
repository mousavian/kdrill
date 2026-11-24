# Right-size inference onto MIG slices

## Concept

**Multi-Instance GPU (MIG)** splits an A100, H100 or newer data-centre GPU
into up to 7 hardware-isolated **GPU instances**. Each one has its own
compute units, memory and memory bandwidth. Unlike time-slicing, a pod on a
MIG slice can't read or exhaust another slice's memory, and its performance
doesn't depend on its neighbours.

Profiles are named `<compute slices>g.<memory>gb`. On an H100 80GB:
`1g.10gb` (7 per GPU), `2g.20gb` (3), `3g.40gb` (2), `4g.40gb`, `7g.80gb`. A
GPU can be cut into a mix, e.g. NVIDIA's `all-balanced` layout for the H100 is
2 × 1g.10gb + 1 × 2g.20gb + 1 × 3g.40gb. Partitions are set up front by an
admin (or the GPU Operator's MIG manager, driven by the
`nvidia.com/mig.config` node label). The scheduler can't resize them.

The device plugin exposes MIG in one of two ways:

- **single** strategy: every GPU on the node uses the same profile, and slices
  are still called `nvidia.com/gpu` (GFD changes `gpu.product` to e.g.
  `NVIDIA-H100-80GB-HBM3-MIG-1g.10gb`).
- **mixed** strategy: each profile is its own resource, like
  `nvidia.com/mig-1g.10gb: 16`, and GFD adds labels such as
  `nvidia.com/mig.strategy=mixed` and `nvidia.com/mig-1g.10gb.count=16`.

With the mixed strategy, **right-sizing** means asking for the smallest
profile that holds the model:

    resources:
      limits:
        nvidia.com/mig-1g.10gb: 1

No node affinity is needed, because only MIG-partitioned nodes advertise these
resources. A pod should ask for either a MIG profile or `nvidia.com/gpu`,
never both: asking for both needs a whole GPU *and* a slice.

## The situation

`h100-mig-1`: 8 H100s in the `all-balanced` layout, which gives 16 × 1g.10gb,
8 × 2g.20gb and 8 × 3g.40gb (no whole GPUs). `h100-1`: 8 whole H100s.
`embed` (8 replicas, a ~3 GB embedding model) and `rerank` (4 replicas, ~15
GB) each ask for a whole `nvidia.com/gpu`. Eight of them hold all of
`h100-1`, four are Pending, and so is the 8-GPU `pretrain` job.

## Your task

- `embed`: each pod requests exactly one `nvidia.com/mig-1g.10gb` and no
  `nvidia.com/gpu`. All 8 Running.
- `rerank`: each pod requests exactly one `nvidia.com/mig-2g.20gb` (the
  smallest profile that fits 15 GB) and no other GPU resource. All 4 Running.
- `pretrain` Running with its 8 whole GPUs.

Rules: keep the replica counts and `pretrain`'s request; don't change the
nodes.

## Useful commands

    kubectl get nodes -L nvidia.com/mig.strategy,nvidia.com/mig.config
    kubectl describe node h100-mig-1 | grep -E 'nvidia.com/(gpu|mig)'
    kubectl get pods -o wide
    kubectl describe pod -l app=pretrain

When you think you're done: `kdrill verify`

## On a real cluster

The MIG manager creates the partitions on the GPU (it drains GPU pods from the
node first), and the device plugin advertises the slices. Here the fake node
simply advertises the resources and labels. Kueue (later lessons) can also
quota MIG profiles, and DRA drivers can expose MIG devices with richer
attributes.

## Read more

- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html
- https://docs.nvidia.com/datacenter/tesla/mig-user-guide/
- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
