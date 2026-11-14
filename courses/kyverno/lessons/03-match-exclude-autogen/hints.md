Start with the stuck Deployment and the policy:

    kubectl -n prod describe rs -l app=api      # FailedCreate ... blocked due to the following policies
    kubectl get clusterpolicy require-run-as-nonroot -o yaml

The Deployment got in because autogen is off (look at the annotation and
`status.autogen`); its Pods are rejected one by one.
---
- Namespaces by label: add `namespaceSelector: {matchLabels: {env: prod}}`
  next to `kinds` in the match filter.
- The exemption: an `exclude.any[].subjects` entry for the ServiceAccount.
  Kyverno will refuse it until you set `spec.background: false` (read the
  error).
- Autogen: delete the `pod-policies.kyverno.io/autogen-controllers` annotation.
- Then fix `api`: `spec.template.spec.securityContext.runAsNonRoot: true`.
---
From the lesson directory:

    kubectl apply -f solution/policy.yaml
    kubectl apply -f solution/api.yaml

(`kubectl apply` won't remove an annotation it didn't add; if the annotation
stays, run `kubectl annotate clusterpolicy require-run-as-nonroot pod-policies.kyverno.io/autogen-controllers-`.)
