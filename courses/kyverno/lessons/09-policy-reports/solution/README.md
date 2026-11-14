# Solution

From the lesson directory:

    kubectl patch clusterpolicy best-practices --type=merge -p '{"spec":{"background":true}}'
    kubectl get polr -A -o wide                    # who fails?
    kubectl apply -f solution/workloads.yaml       # fix them
    kubectl get polr -A -o wide                    # FAIL column 0 for Deployments and Pods
    kubectl apply -f solution/policy.yaml          # now Enforce

What the reports show after background scanning is enabled:

| Workload | Rule | Fix |
|---|---|---|
| team-a/worker | pin-image-tag (`:latest`) | `registry.acme.io/worker:3.7.2` |
| team-a/cache | require-memory-limit | `limits.memory: 512Mi` |
| team-b/embedder | pin-image-tag (no tag means latest) | `registry.acme.io/embedder:1.2.0` |

How reporting works: the **reports controller** evaluates every matching
stored object against policies with `background: true` (on policy change,
on resource change, and every `backgroundScanInterval`, 2 minutes in this
lab), and the admission controller adds results for requests it sees.
Results land in one **PolicyReport** per resource, in the resource's
namespace (cluster-scoped resources: **ClusterPolicyReport**). Because of
autogen, Deployments, ReplicaSets and Pods all get results. Old
ReplicaSets left behind by a rollout keep reporting `fail` until they're
removed (`revisionHistoryLimit`).

Switching to Enforce only after the reports are clean means no team finds
out about the policy from a failed deploy.

Takeaways:
- `background: true` + reports = an inventory of existing violations.
- Roll out: Audit + background, fix or grant exceptions (next lesson), then Enforce.
- `kubectl get polr -A -o wide` is the quickest overview; tools like
  Policy Reporter add a UI and alerts.
