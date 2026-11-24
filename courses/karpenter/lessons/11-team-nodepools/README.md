# Team NodePools that don't overlap

## Concept

One NodePool per kind of capacity is the usual shape of a Karpenter
cluster: general purpose, GPU, spot batch, a team that pays for its own
nodes. With several pools, two questions decide where a pending pod goes:

1. **Which pools can take it?** A pool is compatible if its requirements,
   labels and taints fit the pod's nodeSelector, affinity and tolerations.
   A pod selecting a custom label (`team: team-a`) only fits pools whose
   template *sets* that label; a pool with a taint only takes pods that
   tolerate it.
2. **Which compatible pool first?** The highest `spec.weight`. If several
   compatible pools have the same weight, which one wins is not something to
   rely on. Design pools to be **mutually exclusive** (or weighted on
   purpose).

The tenant pattern uses both sides:

- **label** (`spec.template.metadata.labels: {team: team-a}`): the team's
  pods select it, so they can only be placed by that pool;
- **taint** (`team=team-a:NoSchedule`): everyone else's pods are kept off,
  even ones with no selectors at all;
- **limits**: each team gets its own budget, so one team's runaway job
  can't eat the shared pool;
- per-team choices such as capacity type, families or expiry.

A label without a taint lets other pods drift onto the team's nodes (and
keep them alive). A taint without a label lets the team's pods land on the
shared pool.

## The situation

One NodePool, `shared` (amd64, on-demand, c/m/r, 32 CPUs). Three
namespaces: `team-a` (`etl`, 4 pods), `team-b` (`web`, 3 pods) and
`platform` (`metrics`, 2 pods). Everything shares the same nodes, and the
teams want their own.

## Your task

Create two NodePools with the same `nodeClassRef` and families as `shared`
(amd64, `instance-category` In `[c, m, r]`):

| NodePool | node label | taint | capacity type | limits.cpu |
|---|---|---|---|---|
| `team-a` | `team: team-a` | `team=team-a:NoSchedule` | on-demand | 16 |
| `team-b` | `team: team-b` | `team=team-b:NoSchedule` | spot | 16 |

and point `team-a/etl` and `team-b/web` at their pools (nodeSelector on
`team` plus a toleration).

Result: `etl` (4) on team-a nodes, `web` (3) on team-b spot nodes,
`metrics` (2) on the shared pool, and no pod on another team's nodes.

Rules: don't change NodePool `shared` or `platform/metrics`; keep replicas
and requests; don't create nodes yourself. Expect ~30 s; consolidation then
removes the emptied shared node(s).

## Useful commands

    kubectl get nodepools
    kubectl get nodes -L karpenter.sh/nodepool,team,karpenter.sh/capacity-type
    kubectl get pods -A -o wide | grep -E 'team-|platform'
    kubectl -n team-a describe pod -l app=etl | tail -4
    kubectl -n karpenter logs deploy/karpenter | grep 'created nodeclaim'

When you think you're done: `kdrill verify`

## On a real cluster

Same design on EKS, often with a NodeClass per team too (own subnets,
security groups, IAM role, tags for cost allocation). Admission policy
(Kyverno, Gatekeeper, ValidatingAdmissionPolicy) usually enforces that only
team-a's namespace may tolerate `team=team-a`; taints alone don't stop
another team from adding the toleration.

## Read more

- https://karpenter.sh/docs/concepts/scheduling/#weighted-nodepools
- https://karpenter.sh/docs/concepts/nodepools/
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
