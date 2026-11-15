# Solution

From the lesson directory:

    kubectl apply -f solution/plan.yaml

The arithmetic (peak 40 requests/s x 500 output tokens = 20 000 generated tokens/s, headroom 30%, so a replica is
only counted at 70% of its measured throughput):

| GPU | usable tokens/s | replicas for the peak | cost per hour |
|---|---|---|---|
| L40S | 1400 x 0.7 = 980 | ceil(20000 / 980) = 21 | 21 x 2.00 = 42.00 |
| H100 | 3200 x 0.7 = 2240 | ceil(20000 / 2240) = 9 | 9 x 4.50 = 40.50 |

The H100 costs more per hour but produces more than twice the tokens, so it is cheaper per token: **h100, 9 replicas**.
(Real numbers change with the model, the engine, quantisation and the latency target: measure them.)

- **Zone loss**: with 3 zones, losing one must still leave 9 replicas running on the other two, which then hold half the total each:
  total = ceil(9 x 3 / 2) = ceil(13.5) = **14** replicas (14 GPUs).
- **Nodes**: 14 replicas over 3 zones = 5 per zone (rounded up); a node holds 4 GPUs, so 2 nodes per zone = **6 nodes** (24 GPUs, 14 used: the remainder is
  your spare capacity for rollouts, lesson 23).
- **Autoscaler**: floor = ceil(9 x 25%) = 3 (also one per zone), ceiling = **14**: scaling past it has nowhere to land; add nodes first.

The headroom is not waste: queueing delay explodes as a server nears saturation, so latency targets are met at 60-80%
utilisation. And the plan is a starting point: check it with the autoscaler (lesson 09) and with real load tests.
