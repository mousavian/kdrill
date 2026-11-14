# Solution

`kubectl describe pod` on a Pending trainer pod shows two reasons at once:
the general nodes have `Insufficient cpu` (web took 3 of their 4 CPUs), and the
ML nodes have an `untolerated taint {dedicated: ml}`.

A taint repels; a toleration lets a pod ignore the repulsion. Two things are
needed, and they do different jobs:

- **toleration** — *permits* the pod on the tainted nodes;
- **nodeSelector / node affinity** — *attracts* the pod to the ML pool and keeps
  it off everything else.

Without the node rule, trainer would be allowed anywhere (the ML nodes just
happen to be the only ones with room today). Taints keep others out; they do
not keep your pod in.

    kubectl apply -f solution/trainer.yaml     # from the lesson directory

or in the pod template:

    nodeSelector:
      pool: ml
    tolerations:
    - key: dedicated
      operator: Equal
      value: ml
      effect: NoSchedule

Don't remove the taint: it is what keeps general workloads off the expensive ML
nodes. And don't give web the toleration — it would then be allowed there too.
