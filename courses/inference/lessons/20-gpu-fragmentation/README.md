# Replicas on GPU nodes: one GPU per replica, and fragmentation

Fake pods on fake GPU nodes (**no request is ever served**; the scheduler is real).

## Concept

A model replica asks for GPUs with the **extended resource** `nvidia.com/gpu` in
its `limits` (whole numbers only; requests default to the limit). Which GPU
type a model needs follows from its memory (lesson 04): an 8B model in 16-bit
is about 16 GB of weights and fits on one 24-80 GB GPU; a 70B model needs about 140 GB, so
it is split over 4 GPUs with **tensor parallelism** (`--tensor-parallel-size 4`), and the 4
GPUs must be on **one node**: the layers exchange activations on every
token over NVLink, which node-to-node networks cannot match. A pod therefore
requests `nvidia.com/gpu: 4`, and the scheduler needs a node with 4 *free* GPUs.

That makes GPUs a bin-packing problem, with the scheduler's default
policy working against you: it **spreads** pods, which is right for availability and
wrong for fragmentation. Free GPUs scattered over nodes (1 + 1) cannot start a
4-GPU replica, however much the dashboard says is "free". Solutions: node pools
per model size, scheduler profiles that pack small pods (MostAllocated), priority and
preemption, or a node autoscaler that adds a whole node when a pod is
Pending.

`Pending` is not an error but a statement: read the pod's events
(`0/2 nodes are available: 2 Insufficient nvidia.com/gpu`).

## The situation

Two fake nodes `a100-1` and `a100-2`, each with 4 A100-80GB GPUs. `llm-8b` runs 6
replicas (1 GPU each) and was scheduled first (3 + 3). `llm-70b` has 1 replica needing 4
GPUs and is Pending.

## Your task

Change the **workloads** (not the nodes) so that:

- `llm-70b`'s pod runs, with its 4-GPU request unchanged, alone on its node;
- `llm-8b` has at least 4 replicas, all Running, with its 1-GPU request unchanged;
- no pod is Pending, no node is overbooked.

## Useful commands

    kubectl get pods -o wide
    kubectl describe pod -l app=llm-70b | tail
    kubectl get nodes -L nvidia.com/gpu.product
    kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'

When you think you're done: `kdrill verify`

## On a real cluster

The same objects, plus the NVIDIA device plugin (advertises `nvidia.com/gpu`) and GPU
Feature Discovery (labels such as `nvidia.com/gpu.product`, used in the next lessons and in the
gpu-scheduling course). Nodes are often tainted `nvidia.com/gpu=present:NoSchedule` so that CPU
pods stay away; model pods then need a matching toleration. Multi-node tensor/pipeline parallelism (LeaderWorkerSet) exists
for models bigger than one node, at a high operational price.

## Read more

- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
- https://docs.vllm.ai/en/latest/serving/parallelism_scaling.html
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- https://github.com/NVIDIA/k8s-device-plugin
