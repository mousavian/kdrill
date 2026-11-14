# Drift and expiration roll the fleet for you

## Concept

With node groups, changing the AMI or instance family means a rolling
replacement you script and babysit. With Karpenter you change the
**desired state** and it rolls the fleet.

**Drift**: a node has drifted when it no longer matches what its NodePool
(or NodeClass) says now. Karpenter checks two ways:

- *Requirements*: the node's labels no longer satisfy the pool's
  requirements, e.g. it's amd64 and the pool now says arm64
  (condition `Drifted`, reason `RequirementsDrifted`).
- *Template hash*: Karpenter stamps every NodeClaim with a hash of the
  pool's template (`karpenter.sh/nodepool-hash`). Changing template labels,
  annotations, taints, startupTaints, `expireAfter` or
  `terminationGracePeriod` changes the hash (`NodePoolDrifted`). Budgets,
  `consolidateAfter` and `limits` don't. (On AWS, `EC2NodeClass` changes,
  e.g. a new AMI, drift nodes too.)

Drifted nodes are replaced like consolidation: replacement first, then a
graceful drain respecting PDBs, do-not-disrupt and disruption budgets
(default: 10 % of the pool's nodes at a time).

**Expiration**: `spec.template.spec.expireAfter` (default `720h`, or
`Never`) is the maximum age of a node. An expired node is deleted no matter
what, without waiting for budgets, and its pods are rescheduled (Karpenter
provisions new capacity for them). Use it to bound how stale a node can get
(patches, kernel, credentials).

**`terminationGracePeriod`** caps how long deleting a node may take.
Without it, a PDB that never allows an eviction or a do-not-disrupt pod can
block a drift or expiry drain forever; with it, Karpenter force-deletes
remaining pods once the period runs out.

## The situation

NodePool `default`: amd64, on-demand, category `m`, `expireAfter: 720h`.
In namespace `fleet`, `api` (4 × 1 CPU, multi-arch image, PDB
`maxUnavailable: 1`) runs on an amd64 node.

## Your task

Change NodePool `default`:
- `kubernetes.io/arch` In `[arm64]` (Graviton),
- template label `fleet: graviton-2026` on every node
  (`spec.template.metadata.labels`),
- `expireAfter: 168h` and `terminationGracePeriod: 1h`.

Keep the other requirements. Then let Karpenter do the rest.

Result: `api` (4) Running; every node arm64 with label
`fleet=graviton-2026`; none of the original nodes left; Karpenter replaced
them as `Drifted` (verify looks for its `DisruptionTerminating ... Drifted`
events).

Rules: don't delete or create nodes or NodeClaims yourself; don't change
`api` or its PDB. Expect ~20-60 s.

## Useful commands

    kubectl get nodeclaims -w
    kubectl get nodeclaims -o 'custom-columns=NAME:.metadata.name,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,DRIFTED:.status.conditions[?(@.type=="Drifted")].reason'
    kubectl get nodes -L kubernetes.io/arch,fleet,node.kubernetes.io/instance-type
    kubectl get events -A --field-selector reason=DisruptionTerminating
    kubectl explain nodepool.spec.template.spec.expireAfter

When you think you're done: `kdrill verify`

## On a real cluster

On EKS most drift comes from the `EC2NodeClass`: a new AMI release matched by
`amiSelectorTerms` (e.g. `alias: al2023@latest`) drifts every node, which is
how many teams roll monthly patches. The KWOK provider never reports
NodeClass drift (its `KWOKNodeClass` has nothing to drift on), so here drift
comes only from the NodePool. Pin AMIs in production and promote them
deliberately: `@latest` rolls the whole fleet whenever AWS publishes.

## Read more

- https://karpenter.sh/docs/concepts/disruption/#drift
- https://karpenter.sh/docs/concepts/disruption/#automated-forceful-methods
- https://karpenter.sh/docs/concepts/nodepools/#spectemplatespecexpireafter
