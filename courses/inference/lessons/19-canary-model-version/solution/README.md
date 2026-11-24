# Solution

From the lesson directory:

    kubectl apply -f solution/route.yaml

Two rules in the HTTPRoute:

1. requests with `x-canary: always` go to `v2` only (testers and automated smoke tests can
   always reach the new version, whatever the weights);
2. everything else is split by weight: 90 to `v1`, 10 to `v2`.

Weights are proportions of the rule's total (they do not need to add to 100). Envoy picks the
backend per request, so the share converges to 10% but any short run varies:
verify accepts 1 to 15 out of 60.

A canary protects users from a bad model version, but a model rollout has things a code
rollout does not: quality regressions are not crashes (watch answer quality, refusal rate,
latency and tokens per request on the canary, not just HTTP errors), a new version often
needs different GPU memory or a different engine version, and a stuck rollout wastes GPUs.
Increase the weight in steps (1% -> 10% -> 50% -> 100%) while the metrics hold, keep v1 around until the end for
instant rollback (set v2's weight to 0 or remove it), and with the Inference Extension use an
`InferenceModelRewrite` to split between two *model names* (or adapters) behind one pool.
