Count GPUs per node: `kubectl get pods -o wide` and
`kubectl describe node l40s-1 | grep -A8 'Allocated resources'`. The default
scheduler scores nodes with **LeastAllocated** (on CPU and memory), so it
spread the 6 chat pods 2-2-2. Every node has 2 free GPUs; none has 4.
---
A second scheduler, `gpu-binpack`, runs in kube-system with a profile that
prefers the *most* allocated node (look at its config:
`kubectl -n kube-system get configmap gpu-binpack-scheduler -o yaml`).
Pods choose their scheduler with `spec.schedulerName`. Which workload should
be packed tightly: the many small pods or the one big one?
---
Pack the small pods so whole nodes stay free:

    kubectl patch deploy chat --type merge \
      -p '{"spec":{"template":{"spec":{"schedulerName":"gpu-binpack"}}}}'

The Deployment uses `Recreate`, so all chat pods are replaced and the new ones
pile onto the fewest nodes (4 + 2). `finetune` then fits on the empty node.
