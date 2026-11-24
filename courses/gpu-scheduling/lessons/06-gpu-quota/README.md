# Cap each team's GPUs with ResourceQuota

## Concept

Priority decides who wins when GPUs run out. **Quota** decides how much each
team may take in the first place. The built-in tool is a namespaced
**ResourceQuota**:

    apiVersion: v1
    kind: ResourceQuota
    metadata: {name: gpu-quota, namespace: team-a}
    spec:
      hard:
        requests.nvidia.com/gpu: "4"

For extended resources like GPUs only the `requests.` form is allowed (there's
no `limits.nvidia.com/gpu` and no bare `nvidia.com/gpu`). It's enough, because
extended-resource requests always equal limits. MIG profiles work the same
way, e.g. `requests.nvidia.com/mig-1g.10gb`.

How quota is enforced:

- It is an **admission** check. When a pod is created, the API server adds its
  requests to the namespace's `status.used`. If that would go over `hard`,
  the create is rejected. Nothing is ever evicted, so pods that were running
  before the quota existed keep running, even if usage is over the limit.
- A rejected pod doesn't show up as Pending. It never exists. The
  ReplicaSet or Job records a `FailedCreate` event (`exceeded quota: ...`)
  and retries with backoff. If pods seem to be "missing", run
  `kubectl describe rs` or `kubectl describe job`.
- Quota counts requests, not capacity. Quotas adding up to more GPUs than the
  cluster has is allowed, and quotas adding up to less wastes idle GPUs.

ResourceQuota is a hard per-namespace cap. It can't lend idle GPUs to another
team or queue work until room frees up. That needs Kueue (next lessons).

## The situation

Two nodes with 4 A10Gs each (8 GPUs). team-a's `sweep` (8 trials, 1 GPU each)
started first and holds every GPU. team-b's `serve` (3 × 1 GPU) is Pending.
The agreed split is 4 GPUs per team.

## Your task

- Create a ResourceQuota named `gpu-quota` in **both** `team-a` and `team-b`
  with `requests.nvidia.com/gpu: 4` (and no other quotas in those namespaces).
- Bring team-a within its quota: exactly 4 `sweep` pods Running, and team-a's
  quota showing 4 used.
- team-b's `serve`: all 3 replicas Running.

Rules: `sweep` keeps `replicas: 8` (the quota, not a manual scale-down, holds
it at 4); keep 1 GPU per pod; don't change the nodes.

## Useful commands

    kubectl -n team-a describe quota
    kubectl -n team-a describe rs -l app=sweep          # FailedCreate events
    kubectl get pods -A -o wide -l 'app in (sweep,serve)'
    kubectl -n team-b describe pod -l app=serve

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/policy/resource-quotas/
- https://kubernetes.io/docs/concepts/policy/resource-quotas/#resource-quota-for-extended-resources
