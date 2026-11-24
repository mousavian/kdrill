# Match and exclude precisely; autogen for Pod controllers

## Concept

`match` and `exclude` decide which requests a rule sees. Each holds
`any:` (OR) or `all:` (AND) of **resource filters**:

    match:
      any:
      - resources:
          kinds: [Pod]
          namespaceSelector:          # namespaces by label
            matchLabels: {env: prod}
          operations: [CREATE, UPDATE]
    exclude:
      any:
      - subjects:                     # who sends the request
        - {kind: ServiceAccount, name: backup-agent, namespace: prod}

Inside one filter every field must hold. Filters can use `kinds`, `names`,
`namespaces`, `namespaceSelector`, `selector` (object labels), `operations`,
`annotations`, and request info: `subjects`, `roles`, `clusterRoles`. Prefer
`namespaceSelector` over a list of names: a new prod namespace is then
covered automatically.

**Background mode.** With `background: true` (the default) Kyverno also
scans stored objects (lesson 09). A stored object has no requester, so a
rule that uses `subjects`, `roles` or `request.userInfo` is refused unless
the policy sets `background: false`.

**Autogen.** You write rules for Pods, but most Pods are created by
controllers. Kyverno therefore **auto-generates** rules (`autogen-<rule>`,
`autogen-cronjob-<rule>`) that apply the same check to the Pod template of
Deployments, StatefulSets, DaemonSets, Jobs, ReplicaSets and CronJobs. A bad
Deployment is then rejected when you `kubectl apply` it, with a clear
message. Without autogen the Deployment is accepted, and then the
ReplicaSet controller's Pod creates are rejected. All you see is `0/2`
ready and `FailedCreate` events on the ReplicaSet. The annotation
`pod-policies.kyverno.io/autogen-controllers` limits autogen (`none` turns it
off). `kubectl get clusterpolicy X -o yaml` shows the generated rules under
`status.autogen`.

A catch with subject exclusions: Pods of a Deployment are created by the
ReplicaSet controller, not by the user who applied the Deployment.

## The situation

The Enforce ClusterPolicy `require-run-as-nonroot` applies to every Pod in
every namespace, has autogen switched off, and has no exemptions. The `api`
Deployment in `prod` was applied without complaint but has no Pods.
Namespace `dev` (label `env=dev`) is blocked too, and the nightly
`backup-agent` (ServiceAccount in `prod`, runs bare Pods as root) is
broken.

## Your task

Change `require-run-as-nonroot` (keep the name, rule `run-as-nonroot` stays
Enforce, same message) so that:

- Pods without `spec.securityContext.runAsNonRoot: true` are rejected in
  every namespace labelled `env=prod`, including ones created later, and
  admitted elsewhere (`dev`, unlabelled namespaces);
- requests from ServiceAccount `prod/backup-agent` are exempt; requests from
  other identities (e.g. `prod/deployer`) are not;
- a Deployment with a non-compliant Pod template is rejected when it is
  applied (autogen enabled).

Then fix `api` (not the policy) so that it has 2 replicas, both ready, with
`runAsNonRoot: true` in its Pod template.

verify dry-runs the files in `probes/` in `prod`, `dev`, and two throw-away
namespaces it creates (`kyv-probe-prod` with `env=prod`, `kyv-probe-other`),
and as the two ServiceAccounts (`kubectl --as=system:serviceaccount:prod:...`).

## Useful commands

    kubectl get clusterpolicy require-run-as-nonroot -o yaml    # status.autogen
    kubectl -n prod describe rs -l app=api                      # FailedCreate
    kubectl explain clusterpolicy.spec.rules.match.any.resources
    kubectl explain clusterpolicy.spec.rules.exclude.any.subjects
    kubectl --as=system:serviceaccount:prod:backup-agent -n prod run t --image=nginx --dry-run=server

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/match-exclude/
- https://kyverno.io/docs/policy-types/cluster-policy/autogen/
- https://kyverno.io/docs/policy-types/cluster-policy/policy-settings/
