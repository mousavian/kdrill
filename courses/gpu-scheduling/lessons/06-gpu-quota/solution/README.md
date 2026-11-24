# Solution

    kubectl apply -f solution/quotas.yaml        # from the lesson directory
    kubectl -n team-a delete pod -l app=sweep

The quotas alone change nothing visible: quota is checked when pods are
*created*, so team-a shows `requests.nvidia.com/gpu 8/4` and keeps its 8 pods.
Deleting the sweep pods makes the ReplicaSet recreate them. The first 4 are
admitted, the rest fail with `exceeded quota` (see
`kubectl -n team-a describe rs -l app=sweep`). The 4 freed GPUs go to team-b's
Pending `serve` pods, whose namespace is well within its own quota.

A `kubectl rollout restart` would *not* work here: the new ReplicaSet's pods
are checked against a quota that the old pods already fill, so the rollout
stalls with 0 new pods.

Takeaways:
- `requests.nvidia.com/gpu` is the only quota form for GPUs (and MIG profiles).
- Quota rejects, it never evicts. Plan how existing over-quota usage drains.
- A rejected pod is invisible to `kubectl get pods`; look at the controller's
  events.
- Static quotas leave GPUs idle when a team doesn't use its share. Kueue's
  cohorts (lesson 08) fix that.
