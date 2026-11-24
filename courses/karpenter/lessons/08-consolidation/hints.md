Look at the node: `kubectl get nodeclaims` and
`kubectl describe node <name> | grep -A6 'Allocated resources'`. It is
mostly idle but not empty. What does `WhenEmpty` do with a node that still
has one pod?
---
`kubectl explain nodepool.spec.disruption`. Two fields: the policy
(`WhenEmptyOrUnderutilized`) and `consolidateAfter` (e.g. `15s`). Then watch
`kubectl get nodeclaims -w`: a new small node appears, the old one drains
and disappears.
---
    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

or

    kubectl patch nodepool default --type merge \
      -p '{"spec":{"disruption":{"consolidationPolicy":"WhenEmptyOrUnderutilized","consolidateAfter":"15s"}}}'
