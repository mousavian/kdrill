Look at why the pods wait: `kubectl -n shop describe pod -l app=web`. Two
schedulers have an opinion: kube-scheduler (`FailedScheduling`, no node fits)
and Karpenter (no NodePool to launch from). Karpenter only provisions
through a **NodePool**, and a NodePool points to a **NodeClass**:
`kubectl get kwoknodeclasses`.
---
Field reference: `kubectl explain nodepool.spec.template.spec`. The NodePool
needs `template.spec.nodeClassRef` (group `karpenter.kwok.sh`, kind
`KWOKNodeClass`, name `default`), `template.spec.requirements` for
`kubernetes.io/arch` and `karpenter.sh/capacity-type`, and `limits.cpu`.
Then watch: `kubectl get nodeclaims -w`.
---
    kubectl apply -f solution/nodepool.yaml      # from the lesson directory
    kubectl get nodeclaims                       # TYPE column = instance type
    kubectl -n shop create configmap findings --from-literal=instance-type=<TYPE>
