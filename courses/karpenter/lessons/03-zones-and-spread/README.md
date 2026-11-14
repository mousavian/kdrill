# Zones and topology spread drive where nodes appear

## Concept

Karpenter reads the same scheduling rules kube-scheduler does and launches
nodes that satisfy them. Pods steer provisioning through **well-known
labels** (labels Karpenter knows before the node exists):

- `nodeSelector` / required node affinity on `topology.kubernetes.io/zone`,
  `kubernetes.io/arch`, `karpenter.sh/capacity-type`,
  `node.kubernetes.io/instance-type`, ... narrows the NodeClaim: a pod that
  needs `us-west-2a` gets a node in `us-west-2a`.
- A value nothing offers (a zone the cloud doesn't have, a label Karpenter
  has never heard of) leaves no instance type to launch, and the pod waits
  with a Karpenter `FailedScheduling` event that lists the requirements it
  tried.
- **Topology spread** with `whenUnsatisfiable: DoNotSchedule` is a hard rule,
  and Karpenter creates nodes in the zones needed to satisfy it. With
  `ScheduleAnyway` it's a preference; Karpenter doesn't buy extra nodes for a
  preference.

Two details matter for zone spread:

- **`minDomains`**. kube-scheduler only knows zones that already have
  nodes. If all nodes are in `us-west-2b`, a 6-pod spread over "all zones" is
  happily 6-in-one-zone (skew 0 in a single domain). `minDomains: 3` says
  "there are 3 zones; count the empty ones as 0", so extra pods stay Pending
  until Karpenter brings up nodes in the other zones.
- **`matchLabelKeys: [pod-template-hash]`**. During a rolling update the old
  and new ReplicaSet's pods all match `app: checkout`. Adding the template hash
  makes each rollout spread its own pods.

## The situation

NodePool `general` (amd64, on-demand, c/m/r families, all three zones
`us-west-2a/b/c`, consolidation on). In namespace `store`:
- `checkout` (6 × 1 CPU, 2 GiB) runs, all in one zone. One zone outage takes
  the whole shop down.
- `reports` (2 × 500m) must sit next to its database in **us-west-2a**, but
  asks for `us-west-2d`, so it's Pending.

## Your task

- Give `checkout` a topology spread constraint on
  `topology.kubernetes.io/zone` with `maxSkew: 1`,
  `whenUnsatisfiable: DoNotSchedule` and `minDomains: 3`, so its 6 pods end up
  **2 per zone** across all three zones.
- Make `reports` (2 pods) run in **us-west-2a**.

Rules: don't change NodePool `general`; keep replicas and requests; don't
create nodes yourself. Expect ~30-60 s for the new nodes to come up and the
rollout to finish; consolidation then tidies the old node.

## Useful commands

    kubectl -n store get pods -o wide
    kubectl get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type
    kubectl -n store describe pod -l app=reports | tail -5
    kubectl explain deployment.spec.template.spec.topologySpreadConstraints
    kubectl get nodeclaims -w

When you think you're done: `kdrill verify`

## On a real cluster

The zone names come from kdrill's fake cloud catalogue; on AWS the zones a
NodePool can use are the ones its `EC2NodeClass` subnets live in (and,
optionally, a `topology.kubernetes.io/zone` requirement). Real zones can run
out of an instance type (an insufficient-capacity error); Karpenter then tries
the next cheapest offering. The KWOK provider never runs out, so you won't see
that here. Spread across zones is also what keeps a zonal spot reclaim from
taking out every replica at once.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
- https://karpenter.sh/docs/concepts/scheduling/
- https://kubernetes.io/docs/reference/labels-annotations-taints/#topologykubernetesiozone
