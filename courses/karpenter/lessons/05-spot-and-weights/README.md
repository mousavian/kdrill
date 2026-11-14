# Spot first, on-demand as fallback

## Concept

**Spot** capacity is spare cloud capacity at 60-90 % off, which the cloud can
take back with two minutes' notice. Great for work that tolerates
interruption (batch, CI, rendering, stateless replicas behind enough
headroom); risky for singletons and anything slow to restart.

The label `karpenter.sh/capacity-type` (`spot` / `on-demand`; AWS also has
`reserved`) works like any other requirement:

- A **NodePool** allowing both picks the cheapest offering that fits,
  which is nearly always spot. On a real cloud, when spot is unavailable
  (insufficient capacity), Karpenter falls back to on-demand by itself.
- A **pod** can insist: `nodeSelector: {karpenter.sh/capacity-type: on-demand}`.

**Weights** order NodePools. Karpenter tries pools from the highest
`spec.weight` (1-100; unset counts as 0) to the lowest and uses the first
one that can take the pods. Combined with `limits`, that's a budget:

    spot       weight 50, limit 16 CPU   <- tried first
    on-demand  no weight                 <- takes over when spot can't

When the spot pool's limit is used up, its instance types all "exceed
limits", so the next pool provisions the rest. The same pattern handles
reserved capacity (savings plans, reservations): a high-weight pool with a
limit equal to what you've paid for.

Prices drive the final choice within a pool. In this catalogue spot runs
60-69 % below on-demand and varies by zone and family, so Karpenter's
cheapest pick moves around:
`kubectl get nodes -L karpenter.sh/capacity-type,eks-node-viewer/instance-price`.

## The situation

NodePool `on-demand` (amd64, on-demand, c/m/r, no weight). In namespace
`batch`: `api` (4 × 1 CPU) is Running on on-demand nodes, and `render`
(interruptible rendering jobs, 2 CPU / 4 GiB each) is scaled to 0.

## Your task

1. Create NodePool `spot`: same `nodeClassRef` and families as
   `on-demand` (amd64, `karpenter.k8s.aws/instance-category` In `[c, m, r]`),
   `karpenter.sh/capacity-type` In `[spot]`, `limits.cpu: 16`, and a
   **weight higher than** `on-demand`'s.
2. Keep `api` on on-demand: give it a `nodeSelector` (or required node
   affinity) for `karpenter.sh/capacity-type: on-demand`.
3. Scale `render` to 10 replicas (20 CPUs).

Result: all 10 `render` pods Running, some on spot, the overflow on
on-demand; spot nodes total ≤ 16 CPUs; `api` only on on-demand nodes.

Rules: don't change NodePool `on-demand`; don't pin `render` to a capacity
type; keep the pods' requests; don't create nodes yourself. Create the spot
pool **before** scaling `render`. Nodes appear within ~5 s.

## Useful commands

    kubectl get nodepools                      # WEIGHT column
    kubectl get nodeclaims -L karpenter.sh/nodepool
    kubectl get nodes -L karpenter.sh/capacity-type,karpenter.sh/nodepool,eks-node-viewer/instance-price
    kubectl -n batch get pods -o wide
    kubectl -n karpenter logs deploy/karpenter | grep 'created nodeclaim'

When you think you're done: `kdrill verify`

## On a real cluster

There's no spot market here: offerings never run out and nothing is ever
reclaimed. On AWS, Karpenter picks spot with the price-capacity-optimized
strategy and, with an SQS interruption queue configured
(`--interruption-queue`), cordons and drains a node as soon as its two-minute
warning arrives and launches a replacement. Spot also wants flexibility:
allow many instance types and zones so there's always spare capacity
somewhere. This catalogue only has a few dozen types. Spot-to-spot
consolidation (enabled in this install) also needs at least 15 cheaper
instance types before it replaces one spot node with another.

## Read more

- https://karpenter.sh/docs/concepts/nodepools/#specweight
- https://karpenter.sh/docs/concepts/scheduling/#weighted-nodepools
- https://karpenter.sh/docs/concepts/disruption/#interruption
