# Solution

    kubectl apply -f solution/gpu-nodepool.yaml -f solution/inference.yaml   # from the lesson directory

What happens:
1. The `gpu` pool's template changed, so its existing node is **drifted**
   (`kubectl get nodeclaims -o yaml`: condition `Drifted`, reason
   `NodePoolDrifted`).
2. `inference` rolls out with the toleration. Karpenter replaces the drifted
   node: it launches a tainted GPU node, then drains the old one (events
   `DisruptionLaunching` / `DisruptionTerminating ... Drifted`).
3. The evicted `web` pods don't tolerate the taint, so Karpenter launches a
   small node in the `general` pool for them.

End state: `inference` on a tainted `g6` node, `web` on a `c6i`, no pod
without a GPU request on a GPU node.

Notes:
- Pinning `web` to the general pool would also move it, but every future
  workload would need the same pin. The taint protects the GPU pool from all
  of them.
- Look at the replacement GPU node: both inference pods (1 GPU each) are
  packed onto one 4-GPU `g6.12xlarge`, leaving 2 GPUs idle. That's the next
  lesson.
