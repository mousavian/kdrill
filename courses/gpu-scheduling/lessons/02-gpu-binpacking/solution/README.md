# Solution

The 6 one-GPU `chat` pods were spread 2-2-2 by the default scheduler: its
NodeResourcesFit plugin uses the **LeastAllocated** strategy (and the
BalancedAllocation and PodTopologySpread scores also favour spreading). That
left 2 free GPUs on every node, so the 4-GPU `finetune` pod fits nowhere,
although 6 GPUs are free in total.

Send the small pods to the bin-packing scheduler:

    kubectl patch deploy chat --type merge \
      -p '{"spec":{"template":{"spec":{"schedulerName":"gpu-binpack"}}}}'

(or apply `solution/chat.yaml` from the lesson directory). `chat` uses
`Recreate`, so its pods are deleted and recreated; `gpu-binpack` scores nodes
with **MostAllocated** on `nvidia.com/gpu` (weight 10, CPU and memory 1) and
puts them 4 + 2. The default scheduler retries `finetune` and places it on the
node that is now empty.

Takeaways:
- Spreading is the right default for web services and the wrong one for GPUs:
  it fragments capacity that big jobs need in one piece.
- Fix it per workload with a second scheduler profile (`schedulerName`), or
  cluster-wide by changing the default profile's scoring.
- Packing only affects *new* placements. Already-fragmented nodes need pods to
  be recreated (rollout, or the descheduler) to consolidate.
