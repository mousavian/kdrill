Why are 3 `web` pods Pending? `kubectl -n web describe pod -l app=web | tail -3`
and `kubectl get nodepool default -o jsonpath='{.status.resources}'`. The
pool already owns 4 CPUs of nodes and its limit is 4.
---
`spec.limits` takes any resource name: `cpu`, `memory`, and extended
resources such as `nvidia.com/gpu`. Setting the GPU limit to `"0"` makes
every GPU instance type "exceed the limit", so the pool never launches one.
Set all three in one change.
---
    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

If a GPU node was already launched, delete it:
`kubectl delete nodeclaim <name>` (`kubectl get nodeclaims` shows a `g*` type).
