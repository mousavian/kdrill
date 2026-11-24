# Capacity math: from requests per second to GPUs and autoscaler bounds

No cluster workload: a planning exercise checked by `verify` (the **sim** kind, no pods).

## Concept

GPU capacity is bought in big, expensive units, so "how many do we need?" is a calculation
you should be able to do on paper:

1. **Demand in tokens**, not requests: peak requests/s x average generated tokens per
   request gives output tokens/s (prefill is extra work; a rule of thumb or a measurement folds it
   in). Long outputs, not request counts, are what fills GPUs.
2. **Supply per replica**: measured tokens/s at your latency target with your engine, model, quantisation and GPU. It is
   an input, never a datasheet number.
3. **Headroom**: queueing latency explodes as utilisation nears 100%. Plan for 60-80%.
4. **Replicas** = demand / (supply x (1 - headroom)), rounded up. Compare GPU types by **cost per token**
   (a more expensive GPU can be cheaper per token).
5. **Failure**: to survive losing one of z zones (or spot reclamation of a share of nodes), run
   replicas x z / (z - 1) in total. This is the real cost of availability.
6. **Nodes**: GPUs per node and equal nodes per zone decide how many you buy.
7. **Autoscaler bounds**: the floor covers off-peak and the one-per-zone minimum; the ceiling is what you
   actually have GPUs for (or the budget).

## The situation

The ConfigMap `inputs` holds the numbers: peak 40 requests/s, 500 output tokens on average, 30% headroom, 3 zones, 1 GPU per replica, 4 GPUs per node, off-peak
traffic at 25% of peak, and measured throughput and prices for two GPU types (`l40s`, `h100`).

## Your task

Create the ConfigMap `plan` with these keys (integers as plain numbers):

- `gpu-type`: the type with the lowest hourly cost for the peak load (`l40s` or `h100`);
- `replicas`: replicas of that type for the peak, with headroom;
- `replicas-zone-safe`: total replicas so that losing one zone still leaves `replicas` running;
- `nodes`: GPU nodes to provision, equal in every zone;
- `min-replicas`: the autoscaler floor: the off-peak share of `replicas`, but never fewer than one per zone;
- `max-replicas`: the autoscaler ceiling: `replicas-zone-safe`.

## Useful commands

    kubectl get cm inputs -o yaml
    echo $(( 40 * 500 ))                       # shell arithmetic
    awk 'BEGIN{print 20000/2240}'              # decimals

When you think you're done: `kdrill verify` (it recomputes everything from the inputs).

## On a real cluster

Measure with the engine's own benchmark (`vllm bench serve`, `llmperf`, the llm-d benchmark harness) at several
concurrency levels and pick the knee of the throughput/latency curve. Account for prefill-heavy workloads (RAG, long
documents), prefix caching hits, speculative decoding, and mixed model sizes. Spot GPUs change the failure model; reserved
capacity changes the price.

## Read more

- https://docs.vllm.ai/en/latest/benchmarking/
- https://github.com/llm-d/llm-d-benchmark
- https://sre.google/sre-book/handling-overload/
