`kubectl describe pod` on a Pending trainer pod: the event lists the ML nodes as
"untolerated taint" and the general nodes as "Insufficient cpu". Look at the
taint with `kubectl describe node ml-1 | grep -A2 Taints`.
---
A pod can only land on a tainted node if it has a matching **toleration**. But a
toleration only lifts the ban; it doesn't make the pod prefer those nodes. To
keep trainer *only* on the ML pool you also need a node rule on the label
`pool=ml` (nodeSelector or required node affinity).
---
In the trainer pod template add:

    nodeSelector:
      pool: ml
    tolerations:
    - key: dedicated
      operator: Equal
      value: ml
      effect: NoSchedule

Apply it with `kubectl edit deploy trainer`, or `kubectl apply -f solution/trainer.yaml`.
