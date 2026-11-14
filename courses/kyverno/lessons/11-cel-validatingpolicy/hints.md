Compare the two policies and what each does today:

    kubectl get clusterpolicy require-limits -o yaml
    kubectl get validatingpolicy require-memory-limits -o yaml     # status.conditionStatus, status.generated
    kubectl explain validatingpolicy.spec --api-version=policies.kyverno.io/v1
    kubectl explain validatingpolicy.spec.autogen --api-version=policies.kyverno.io/v1

The draft only audits, only looks at `containers`, only matches Pods, and
doesn't generate a ValidatingAdmissionPolicy.
---
- `validationActions: [Deny]`.
- Match Deployments too: a second `resourceRules` entry
  (`apiGroups: [apps]`, `resources: [deployments]`).
- Use `variables` to find the Pod spec for both kinds:
  `object.kind == 'Pod' ? object.spec : object.spec.template.spec`, then build
  the list `containers + initContainers` (initContainers may be absent: `has()`)
  and the names missing a memory limit with `.filter(...)` and `.map(c, c.name)`.
- `messageExpression` to put the names in the message.
- `autogen: {validatingAdmissionPolicy: {enabled: true}, podControllers: {controllers: []}}`.
- Then `kubectl delete clusterpolicy require-limits`.
---
From the lesson directory:

    kubectl apply -f solution/validatingpolicy.yaml
    kubectl delete clusterpolicy require-limits
    kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
