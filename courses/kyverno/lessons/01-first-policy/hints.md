Look at what the policy says and what it does today:

    kubectl get clusterpolicy require-team-label -o yaml
    kubectl -n shop run test --image=nginx --dry-run=server

The dry-run is admitted, silently, because the rule is in Audit mode.
`kubectl explain clusterpolicy.spec.rules.validate` lists the fields.
---
Three things to change in the policy: `failureAction: Enforce`, the
`message`, and the pattern value. In Kyverno patterns `*` means "any value,
even empty"; `?*` means "at least one character".

Then the Deployment: after Enforce, a Pod template without a `team` label is
rejected (Kyverno even checks the Deployment itself, more in lesson 03), so
add `team: <something>` under `spec.template.metadata.labels`.
---
From the lesson directory:

    kubectl apply -f solution/policy.yaml
    kubectl apply -f solution/web.yaml

`solution/web.yaml` adds `team: shop` to the Pod template; the rollout
replaces both Pods with labelled ones.
