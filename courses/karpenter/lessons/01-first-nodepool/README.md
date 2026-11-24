# Your first NodePool

## Concept

The scheduler only places pods on nodes that exist. When nothing fits, pods
stay `Pending` with reason `Unschedulable`. **Karpenter** watches for exactly
those pods and buys capacity for them:

1. It **batches** pending pods for a moment (here: until 1 s passes with no
   new pod, at most 10 s), so a scale-up of 50 replicas becomes one decision.
2. It simulates scheduling. For every **NodePool** it filters the cloud's
   instance types by the pool's `requirements` and by what the pods need
   (requests, nodeSelector, affinity, tolerations), then packs the pods into
   as few new nodes as it can.
3. For each new node it creates a **NodeClaim**: "one instance, one of these
   types, in one of these zones". The cloud provider launches the cheapest
   offering that matches and the NodeClaim records what it got.
4. The node registers and becomes Ready, and kube-scheduler binds the pods.
   Karpenter never binds pods itself.

The objects:

- **NodePool** (`karpenter.sh/v1`, cluster-scoped): *what* Karpenter may
  launch (requirements, taints, labels, limits) and when it may take nodes
  away again (`disruption`, later lessons).
- **NodeClass**: *how* to launch on a particular cloud. On AWS that's an
  `EC2NodeClass` (AMI, subnets, security groups, IAM role). This cluster's
  provider is KWOK, so its NodeClass is a `KWOKNodeClass` with almost nothing
  in it. A NodePool points to one with `spec.template.spec.nodeClassRef`.
- **NodeClaim**: one per node Karpenter launched. `kubectl get nodeclaims`
  is the quickest view of the fleet: type, capacity type, zone, node, ready.

Requirements use node-label keys: `kubernetes.io/arch`,
`karpenter.sh/capacity-type` (`spot` / `on-demand`),
`node.kubernetes.io/instance-type`, `topology.kubernetes.io/zone`, ...
`limits` caps the total resources of all nodes in the pool.

## The situation

Karpenter runs in namespace `karpenter`. Its fake cloud offers 36 instance
types (`kubectl -n karpenter get cm instance-types -o jsonpath='{.data.catalog\.txt}'`).
The KWOKNodeClass `default` exists, but there's no NodePool. In namespace
`shop`, Deployment `web` (4 replicas, 1 CPU and 2 GiB each) is Pending.

## Your task

Create NodePool `default`:
- `nodeClassRef` to the KWOKNodeClass `default` (group `karpenter.kwok.sh`),
- requirements: `kubernetes.io/arch` In `[amd64]` and
  `karpenter.sh/capacity-type` In `[on-demand]`,
- `limits.cpu: 32`.

Result: all 4 `web` pods Running on nodes from NodePool `default` (all amd64,
on-demand), and the NodePool is Ready. Then find out which instance type
Karpenter launched and record it in ConfigMap `findings` (namespace `shop`)
under key `instance-type`.

Rules: don't change `web` (replicas, requests); don't create nodes yourself.

Nodes appear within ~5 s of creating the NodePool.

## Useful commands

    kubectl -n shop describe pod -l app=web          # Events: FailedScheduling, Nominated
    kubectl explain nodepool.spec.template.spec
    kubectl get nodepools,nodeclaims
    kubectl describe nodeclaim                       # requirements, chosen type, events
    kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/capacity-type,topology.kubernetes.io/zone
    kubectl -n karpenter logs deploy/karpenter | grep -E 'provisionable|nodeclaim'

When you think you're done: `kdrill verify`

## On a real cluster

On EKS the NodeClass is an `EC2NodeClass` (`karpenter.k8s.aws/v1`) with
`amiSelectorTerms`, `role`, `subnetSelectorTerms` and
`securityGroupSelectorTerms`, and launching takes 30-90 s (EC2 boot, kubelet
join), not 2. Here the KWOK provider creates the Node object directly and
KWOK marks it Ready; everything before that (batching, instance selection,
NodeClaims, limits) is the real Karpenter code. Images are never pulled, so
an amd64-only image on an arm64 node would "work" here. On AWS it wouldn't.

## Read more

- https://karpenter.sh/docs/concepts/
- https://karpenter.sh/docs/concepts/nodepools/
- https://karpenter.sh/docs/concepts/nodeclaims/
- https://karpenter.sh/docs/concepts/scheduling/
