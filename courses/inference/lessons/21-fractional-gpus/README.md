# Packing small models: MIG slices instead of whole GPUs

Fake pods on fake GPU nodes (**no request is ever served**).

## Concept

Small models do not need a GPU: a 568M-parameter embedding model uses 9 GB of an
80 GB card and a fraction of its compute. Giving it a whole GPU wastes 90% of the
most expensive resource in the cluster. Ways to share one GPU:

- **MIG** (Multi-Instance GPU): hardware partitions with isolated memory and compute
  (A100/H100/B200: up to 7 instances, profiles like `1g.10gb`, `2g.20gb`,
  `3g.40gb`). Predictable, safe, fixed sizes, reconfiguring means draining the GPU.
- **Time-slicing**: the device plugin advertises one GPU as several `nvidia.com/gpu`;
  workloads take turns. Any GPU, no isolation: one pod can use all the memory.
- **MPS**: processes share the GPU concurrently with configurable limits.
- **One server, many models**: multi-model servers or LoRA adapters (lesson 16) on a
  shared base model.

With MIG "mixed" strategy each profile is its own extended resource
(`nvidia.com/mig-1g.10gb`), so a pod requests the slice size it needs and the
scheduler counts slices. The risk is choosing by availability instead of by memory:
a slice that is too small schedules happily and fails at load.

## The situation

Three fake nodes: `whole-1` (2 H100s, advertising `nvidia.com/gpu: 2`, serving `chat`),
`mig-80` (an 80 GB A100 cut into 7 slices of `1g.10gb`) and `mig-40` (a 40 GB A100 cut into 7 slices
of `1g.5gb`). `embed` (6 replicas of a model needing about 9 GB of GPU memory) requests a whole GPU each, so
all six are Pending.

## Your task

Edit `embed` (nothing else) so that all six replicas run on `mig-80`: request the smallest slice profile
the model fits in, and no whole GPU. `chat` and the fleet stay as they are.

## Useful commands

    kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,MIG10:.status.allocatable.nvidia\.com/mig-1g\.10gb'
    kubectl get nodes -L nvidia.com/mig.config,nvidia.com/gpu.product
    kubectl describe pod -l app=embed | tail
    kubectl get pods -o wide

When you think you're done: `kdrill verify`

## On a real cluster

The NVIDIA GPU Operator configures MIG through the `nvidia.com/mig.config` node label
(profiles such as `all-1g.10gb` or a custom layout) and the device plugin then
advertises the slices. Changing the layout needs the GPU to be idle. Cloud GPU
nodes (GKE, EKS) support MIG; managed inference services often hide it. Cheaper than
whole GPUs for embedding, reranking, classifier and small chat models.

## Read more

- https://docs.nvidia.com/datacenter/tesla/mig-user-guide/
- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html
- https://github.com/NVIDIA/k8s-device-plugin#shared-access-to-gpus
- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
