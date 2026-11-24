# Solution

    kubectl apply -f solution/policy.yaml      # from the lesson directory

Three generate rules, all triggered by Namespaces with a `tenant` label:

| Rule | Generates | Source |
|---|---|---|
| `default-deny` | NetworkPolicy `default-deny` (deny all ingress) | `data` (inline) |
| `gpu-quota` | ResourceQuota `gpu-quota`, `requests.nvidia.com/gpu: 4` | `data` |
| `ca-bundle` | ConfigMap `ca-bundle` | `clone` from `platform/ca-bundle` |

- `synchronize: true`: Kyverno owns the downstream object. If it's deleted
  it comes back; if it's edited it is reverted; for `clone`, changes to the
  source are copied. Deleting the policy deletes the downstream objects too
  (unless `orphanDownstreamOnPolicyDelete: true`).
- `generateExisting: true`: generate for trigger objects that already exist
  when the policy is created. Without it only new or updated namespaces get
  the objects.

How it runs: the admission controller sees the Namespace request and records
an **UpdateRequest** (`kubectl -n kyverno get updaterequests`); the
**background controller** then creates the objects with its own
ServiceAccount. That's why it needs RBAC for every kind it generates (the
chart grants NetworkPolicies, ResourceQuotas, ConfigMaps, LimitRanges, Roles
and RoleBindings by default; more via aggregated ClusterRoles) and why
results appear a moment after the namespace.

Takeaways:
- Generate turns "every namespace needs X" into a guarantee.
- `synchronize` decides whether it's a one-time default (false: users may
  change it) or an enforced baseline (true).
- Check UpdateRequests and the background controller's logs when nothing
  appears.
