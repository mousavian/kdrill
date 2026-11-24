# Right-size GPU instances

## Concept

GPU instances are where Karpenter's choices cost real money, and two habits
from static GPU node groups backfire.

**1. Select by labels Karpenter knows before launch.** On a running GPU node,
NVIDIA GPU feature discovery adds labels like
`nvidia.com/gpu.product=NVIDIA-L4`. Karpenter can't launch a node *for* that
label: no instance type advertises it ahead of time, so the pod waits
forever. Use the provider's instance labels instead (on AWS):

| Label | Values here |
|---|---|
| `karpenter.k8s.aws/instance-gpu-name` | `a10g`, `l4`, `a100`, `h100` |
| `karpenter.k8s.aws/instance-gpu-count` | `1`, `4`, `8` |
| `karpenter.k8s.aws/instance-gpu-manufacturer` | `nvidia` |
| `karpenter.kwok.sh/instance-family` | `g5`, `g6`, `p4d`, `p5` |

**2. Don't let one pod buy a big box.** Karpenter picks the cheapest instance
that fits *the set of pods it is placing together*:

- A pod pinned to `a100` gets a `p4d.24xlarge`, the only A100 type: 8 GPUs at
  ~$22/h for a 1-GPU job. Ask for the GPU *capability* you need (memory,
  generation), not a brand: a 24 GB L4 or A10G costs under $1/h.
- Several 1-GPU pods pending at once are packed onto one multi-GPU instance
  (three pods → a 4-GPU `g6.12xlarge`, one GPU idle, and the 4-GPU type
  costs more per GPU than four 1-GPU ones). Requiring
  `instance-gpu-count: "1"` gives each pod its own small instance; a
  dedicated 1-GPU NodePool does the same for a whole class of workloads.

Watch two numbers: idle GPUs (allocatable minus requested) and the fleet's
hourly price. Each fake node carries its price as the label
`eks-node-viewer/instance-price` (the label the eks-node-viewer tool reads).

## The situation

NodePool `gpu` (families `g` and `p`, on-demand, tainted
`nvidia.com/gpu=true:NoSchedule`, consolidation on). In namespace `ai`:
- `chat` (3 × 1 GPU): selects `nvidia.com/gpu.product: NVIDIA-L4` and is
  Pending.
- `eval` (1 × 1 GPU, needs ≥ 24 GB): pinned to `a100`, running alone on a
  `p4d.24xlarge`.
- `train` (8 × H100) on a `p5.48xlarge`: correct, leave it alone.

## Your task

- `chat` runs on **L4** GPUs (`instance-gpu-name` `l4`).
- `eval` runs on a **24 GB** GPU: `l4` or `a10g`.
- The fleet has **no idle GPUs**, and the GPU nodes together cost **at most
  $59.00/h** (sum of `eks-node-viewer/instance-price`).

Rules: change only `chat`'s and `eval`'s placement (selectors/affinity);
keep replicas and resources; don't change NodePool `gpu` or `train`; don't
create nodes yourself. New nodes take ~5 s; an emptied node is removed by
consolidation ~15-30 s later.

## Useful commands

    kubectl -n ai describe pod -l app=chat | tail -4
    kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.k8s.aws/instance-gpu-name,karpenter.k8s.aws/instance-gpu-count,eks-node-viewer/instance-price
    kubectl describe node <name> | grep -A8 'Allocated resources'
    kubectl -n karpenter get cm instance-types -o jsonpath='{.data.catalog\.txt}' | grep -E 'g5|g6|p4d|p5'
    kubectl get nodeclaims -w

When you think you're done: `kdrill verify`

## On a real cluster

The `karpenter.k8s.aws/instance-gpu-*` labels are real AWS-provider labels;
kdrill's catalogue adds them to the KWOK offerings so you can use the same
selectors. Real GPU capacity is scarce: an H100 or A100 request often hits
insufficient-capacity errors and Karpenter moves on to the next type or zone
(so broader requirements launch faster). Capacity reservations / Capacity
Blocks show up as `karpenter.sh/capacity-type: reserved`. None of that is
simulated here. Prices are rounded late-2025 us-west-2 list prices.

## Read more

- https://karpenter.sh/docs/reference/instance-types/
- https://karpenter.sh/docs/concepts/scheduling/#labels
- https://karpenter.sh/docs/concepts/scheduling/#acceleratorsgpu-resources
