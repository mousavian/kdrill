# Solution

    kubectl apply -f solution/policy.yaml      # from the lesson directory

Two changes:

- `spec.mutateExistingOnPolicyUpdate: true`. A mutate-existing rule is
  triggered by admission requests for its *trigger* kind (here: a Namespace
  being created or updated). When the policy is created or changed, this flag
  also runs the rule for every existing trigger, so the Deployments that
  existed before the policy get labelled too.
- A second entry in `mutate.targets` for StatefulSets.

How it runs: the admission controller sees the Namespace update and records
an UpdateRequest; the background controller then fetches each target and
applies the patch with its own ServiceAccount. It needs `update`/`patch` on
the target kinds (here granted for Deployments and StatefulSets through
the chart's `backgroundController.rbac.clusterRole.extraResources`). Missing
RBAC shows up as failed UpdateRequests and in the background controller's
logs, not as an admission error.

Variables: `request.object` is the trigger (Namespace); `target` is the
object being patched (e.g. `{{ target.metadata.name }}`). JMESPath needs quotes
around keys with `-`: `labels."cost-center"`; Kyverno rejects the policy
otherwise.

Only `metadata.labels` is patched. Touching `spec.template` would roll every
Pod.

Limitation: a Deployment created *later* in research isn't labelled until
the namespace changes again. Add a normal (admission) mutate rule for
Deployments that looks the label up from the Namespace; lesson 07 shows how
to read other objects.
