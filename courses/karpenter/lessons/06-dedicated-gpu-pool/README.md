# A dedicated GPU pool with taints

## Concept

Karpenter packs pending pods onto as few new nodes as it can, and any pod
that is *compatible* with a node may share it. If a GPU pod and three web
pods are pending together, one GPU instance big enough for all of them is
often the "cheapest" answer, and your web tier now lives on a $4/h GPU box.
Worse, those web pods keep the GPU node busy, so it can't be consolidated
away when the GPU work ends.

The fix is the same as for hand-managed node groups, declared on the
NodePool:

- `spec.template.spec.taints` puts a taint on every node the pool
  launches, e.g. `nvidia.com/gpu=true:NoSchedule`. Karpenter knows that a pod
  without a matching toleration can't use the pool, so it never packs such a
  pod onto those nodes or launches them for it.
- GPU pods add the toleration. They still need to *request* `nvidia.com/gpu`;
  the toleration only allows them in.

`spec.template.spec.startupTaints` is different: taints a node starts with
and that some agent removes when the node is ready (e.g. a GPU driver or CNI
installer). Karpenter assumes they will go away, so pods don't need to
tolerate them to get a node provisioned. Use it for "not ready yet", not for
"reserved for GPUs".

Changing a NodePool's template (taints, labels, startupTaints...) makes the
existing nodes **drifted**: they no longer match their pool's spec. Karpenter
replaces drifted nodes on its own, launching a replacement first and then
draining the old node, respecting disruption budgets (lessons 9-10).

## The situation

Two NodePools: `general` (c/m/r families) and `gpu` (`g` family, up to 8
GPUs, no taint). In namespace `ml`, `web` (3 × 1 CPU) and `inference`
(2 × 1 GPU) were created together, and Karpenter put all five pods on one
`g6.12xlarge`.

## Your task

- Taint NodePool `gpu`'s nodes `nvidia.com/gpu=true:NoSchedule` (a
  template taint, not a startup taint).
- Let `inference` tolerate it.

Result: `inference` (2) Running on GPU-pool nodes; `web` (3) Running on
general-pool nodes; every GPU node carries the taint; no pod without a GPU
request runs on a GPU node.

Rules: change only the `gpu` pool's taints (keep its requirements, limits,
nodeClassRef); don't change NodePool `general`; don't pin `web` with a
nodeSelector or affinity; keep replicas and requests; don't create nodes
yourself. The drift replacement takes ~15-60 s.

## Useful commands

    kubectl -n ml get pods -o wide
    kubectl get nodeclaims -L karpenter.sh/nodepool -w
    kubectl get nodeclaims -o 'custom-columns=NAME:.metadata.name,DRIFTED:.status.conditions[?(@.type=="Drifted")].reason'
    kubectl get events --field-selector reason=DisruptionTerminating
    kubectl explain nodepool.spec.template.spec.taints

When you think you're done: `kdrill verify`

## On a real cluster

On EKS a GPU pool usually also selects GPU AMIs in its `EC2NodeClass`, and the
NVIDIA device plugin (or GPU Operator) DaemonSet must tolerate the taint, or
it never runs and the node never advertises `nvidia.com/gpu`. Karpenter
doesn't wait for that: it already knows each instance type's GPU count. Here
KWOK nodes report `nvidia.com/gpu` straight away. A common startup taint on
GPU nodes is one the GPU Operator removes once the driver is loaded.

## Read more

- https://karpenter.sh/docs/concepts/nodepools/#spectemplatespectaints
- https://karpenter.sh/docs/concepts/scheduling/#taints-and-tolerations
- https://karpenter.sh/docs/concepts/disruption/#drift
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
