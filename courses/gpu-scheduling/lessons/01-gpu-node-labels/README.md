# Read the GPU labels, pick the right GPU

## Concept

`nvidia.com/gpu: 4` in a node's capacity only says "four GPUs". It doesn't say
which model, how much memory each has, or whether they are shared. On a real
cluster three add-ons (usually installed together by the NVIDIA GPU Operator)
add that information:

- **Node Feature Discovery (NFD)** scans the hardware and adds generic labels
  such as `feature.node.kubernetes.io/pci-10de.present=true` (10de is NVIDIA's
  PCI vendor ID).
- **GPU Feature Discovery (GFD)** adds `nvidia.com/*` labels per node:
  `gpu.product` (e.g. `NVIDIA-H100-80GB-HBM3`, `Tesla-T4`), `gpu.memory`
  (MiB per GPU), `gpu.count`, `gpu.family` (`turing`, `ampere`,
  `ada-lovelace`, `hopper`), `gpu.compute.major/minor` (CUDA compute
  capability), plus sharing and MIG labels you'll meet later. The GPU Operator
  also sets `nvidia.com/gpu.present=true`.
- The **device plugin** advertises the countable resource `nvidia.com/gpu`
  that pods request in `limits`.

The scheduler only counts `nvidia.com/gpu`. Picking the *kind* of GPU is up to
you, with node affinity on these labels. Some habits that pay off:

- **Select on the capability you need, not on the product name.** A model that
  needs more than 48 GB per GPU should say `nvidia.com/gpu.memory Gt 70000`
  (`Gt`/`Lt` compare label values as integers), so it still matches when H200
  nodes join the fleet.
- Use `In` on `gpu.family` or `gpu.product` to keep cheap workloads on cheap
  GPUs. Otherwise the default scheduler happily puts a 1-GPU job on an
  expensive 8×H100 node, because that node has the most free CPU.
- Keep CPU-only pods off GPU nodes (`DoesNotExist` on a GPU label, or a taint
  on the GPU nodes, which is what most clusters do).

## The situation

The fleet has 1-GPU T4 nodes, a 4×A10G, a 4×L40S, an 8×H100 and one CPU node.
`llm-serve` (a 70B model, tensor-parallel over 4 GPUs) is Pending.
`whisper` and the CPU-only `etl` run, but on nodes they should not be using.

## Your task

Fix placement with **required** node affinity on the GPU labels:

- `llm-serve`: both replicas Running on GPUs with more than 70 GB of memory.
  Use `nvidia.com/gpu.memory` with operator `Gt` (any threshold that admits the
  H100's 81559 MiB and excludes the L40S's 46068 MiB). Don't select on
  `nvidia.com/gpu.product` at all.
- `whisper`: Running only on Turing or Ampere GPUs: a required term
  `nvidia.com/gpu.family In [turing, ampere]` (no other families).
- `etl`: Running only on nodes without GPUs: a required term with
  `DoesNotExist` on `nvidia.com/gpu.present` (or on
  `feature.node.kubernetes.io/pci-10de.present`).

Rules:
- Keep the replica counts (2, 2, 3) and the GPU requests (4 and 1 per pod).
- Don't change the nodes (labels, taints, capacity) or add nodes.

## Useful commands

    kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.memory,nvidia.com/gpu.family,nvidia.com/gpu.count
    kubectl get node h100-1 -o jsonpath='{.metadata.labels}' | tr ',' '\n'
    kubectl get pods -o wide
    kubectl describe pod -l app=llm-serve
    kubectl edit deploy llm-serve

When you think you're done: `kdrill verify`

## On a real cluster

The labels here are typed in by the lesson. On real hardware the GPU Operator
runs NFD, GFD and the device plugin as DaemonSets, and the values come from the
driver (NVML). Exact label values differ by GPU and driver version, so check
`kubectl get node <name> --show-labels` before writing affinity rules.

## Read more

- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html
- https://kubernetes-sigs.github.io/node-feature-discovery/stable/get-started/index.html
