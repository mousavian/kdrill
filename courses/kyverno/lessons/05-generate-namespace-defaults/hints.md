Look at what exists and what Kyverno has been asked to do:

    kubectl get networkpolicy,resourcequota,configmap -n team-a
    kubectl get clusterpolicy tenant-defaults -o yaml
    kubectl -n kyverno get updaterequests          # pending/failed generate work
    kubectl explain clusterpolicy.spec.rules.generate

Create a namespace with `kubectl create ns t1; kubectl label ns t1 tenant=t1`
and see what appears in it.
---
- One rule per generated object: copy the `default-deny` rule for a
  `ResourceQuota` (`data.spec.hard: {requests.nvidia.com/gpu: "4"}`) and a
  `ConfigMap` that uses `clone: {namespace: platform, name: ca-bundle}`
  instead of `data`.
- `synchronize: true` on all three, and `generateExisting: true` so team-a
  and team-b (which existed before the policy) get them too.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
    kubectl get networkpolicy,resourcequota,configmap -n team-b

The background controller processes generate requests asynchronously; give
it a few seconds.
