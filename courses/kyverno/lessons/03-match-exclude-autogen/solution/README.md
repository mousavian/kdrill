# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml
    kubectl annotate clusterpolicy require-run-as-nonroot pod-policies.kyverno.io/autogen-controllers- 2>/dev/null
    kubectl apply -f solution/api.yaml

Changes to the policy:

- `namespaceSelector: {matchLabels: {env: prod}}` in the match filter: any
  namespace labelled `env=prod`, now or later. `namespaces: [prod]` would
  miss `kyv-probe-prod`.
- `exclude.any[].subjects`: the `prod/backup-agent` ServiceAccount.
- `background: false`: required as soon as a rule depends on the requester
  (subjects, roles, clusterRoles, `request.userInfo`). Background scans look
  at stored objects, which have no requester; Kyverno rejects the policy
  otherwise.
- The `autogen-controllers: none` annotation is gone, so `status.autogen`
  now lists `autogen-run-as-nonroot` (Deployment, StatefulSet, DaemonSet,
  Job, ReplicaSet, ReplicationController) and `autogen-cronjob-run-as-nonroot`.
  The match, exclude and message are copied into them.

`api`: adding `runAsNonRoot: true` to the Pod template starts a new
ReplicaSet whose Pods pass. The old ReplicaSet had been retrying with
backoff, logging `FailedCreate` events.

Gotcha: excluding `backup-agent` exempts the requests *it* makes. If it
applied a Deployment, autogen would let the Deployment in, but the Pods
are created by `system:serviceaccount:kube-system:replicaset-controller`
and would still be rejected. Exempt by namespace or label for workloads.

Takeaways:
- Scope by labels (namespaceSelector / selector), not names.
- Keep autogen on: errors at apply time beat silent FailedCreate.
- Request-based matching (who) means `background: false`.
