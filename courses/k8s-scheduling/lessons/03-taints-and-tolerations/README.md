# Run the trainer on the ML pool

## Concept

A **taint** on a node repels pods; a **toleration** on a pod lets it ignore a
matching taint. A taint has a key, an optional value and an effect:

    kubectl taint nodes ml-1 dedicated=ml:NoSchedule

Effects:
- `NoSchedule` — new pods without a matching toleration are not scheduled here
  (running pods stay).
- `PreferNoSchedule` — a soft version: the scheduler tries to avoid the node.
- `NoExecute` — also evicts running pods that don't tolerate it.

A toleration matches a taint by key, value and effect:

    tolerations:
    - key: dedicated
      operator: Equal        # or Exists (then no value)
      value: ml
      effect: NoSchedule

The point that trips people up: **a toleration permits, it does not attract.**
A pod that tolerates the ML taint may still be scheduled on any ordinary node
too. Taints keep *other* pods away from special nodes; to keep *your* pod on
them you need a node rule as well (a `nodeSelector` or node affinity on a label
the nodes carry, here `pool=ml`). The standard recipe for a dedicated node pool
is therefore: taint the nodes, label the nodes, and give the pool's workloads
**both** a toleration and a node selector.

Note that kubelet-managed taints such as `node.kubernetes.io/not-ready` work
the same way (pods get automatic tolerations for those).

## The situation

Four nodes: `general-1` and `general-2` run `web` and are almost full. Two ML
nodes, `ml-1` and `ml-2`, are labelled `pool=ml` and tainted
`dedicated=ml:NoSchedule`. The `trainer` Deployment (2 replicas) is Pending:
it doesn't fit on the general nodes and doesn't tolerate the ML taint.

## Your task

Get both `trainer` pods Running on the ML nodes — and only ever there.

Rules:
- `trainer` pods must have a toleration for the `dedicated` taint **and** a hard
  node rule for `pool=ml` (`nodeSelector`, or required node affinity with
  `In` and value `ml`).
- Both ML nodes keep their taint `dedicated=ml:NoSchedule`.
- `web` is left alone: 2 replicas, no tolerations, none on ML nodes.
- Keep 2 replicas of `trainer`; don't add or edit nodes.

## Useful commands

    kubectl get nodes -L pool
    kubectl describe node ml-1 | grep -A3 Taints
    kubectl describe pod <pending-pod>
    kubectl get pods -o wide
    kubectl edit deploy trainer

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
