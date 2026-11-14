# Solution

From the lesson directory:

    kubectl apply -f solution/validatingpolicy.yaml
    kubectl delete clusterpolicy require-limits
    kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding

The ValidatingPolicy, piece by piece:

- `matchConstraints.resourceRules`: Pods **and** Deployments (API group,
  version, resource, operations), same shape as a Kubernetes VAP.
- `variables`: `podSpec` picks `object.spec` or `object.spec.template.spec`;
  `allContainers` adds initContainers when present (`has(...)`); `missing`
  is the list of names without `resources.limits.memory`.
- `validations[].expression` must be true to pass; `messageExpression`
  builds the message from the names.
- `validationActions: [Deny]` (also `Audit`, `Warn`).
- `autogen.validatingAdmissionPolicy.enabled: true`: Kyverno writes a
  `ValidatingAdmissionPolicy` `vpol-require-memory-limits` and its binding,
  and stops handling the policy in its own webhook. The API server evaluates
  it in-process: no webhook round-trip, and it keeps working when Kyverno is
  down. Kyverno still uses the policy for background scans and reports.
- `podControllers.controllers: []`: a VAP can't include Kyverno's
  Pod-controller autogen, so Kyverno only generates one when autogen is off
  (`status.conditionStatus.message` tells you if it skipped). That's why
  Deployments are matched explicitly.

Comparing the two generations:

| | ClusterPolicy (kyverno.io/v1) | ValidatingPolicy (policies.kyverno.io/v1) |
|---|---|---|
| language | patterns, anchors, JMESPath | CEL (same as Kubernetes VAP) |
| status in 1.19 | supported, deprecation warning | the recommended type |
| runs in | Kyverno webhook | Kyverno webhook, or natively as a VAP |
| extras | mutate/generate/verifyImages in one kind | separate kinds: MutatingPolicy, GeneratingPolicy, ImageValidatingPolicy, DeletingPolicy |

Kyverno's CEL types add libraries the native VAP doesn't have (HTTP calls,
resource lookups, image data, JSON parsing); policies that use them can't
become a VAP but still run in Kyverno's webhook. Kyverno's migration guide
and `kyverno migrate` help convert existing ClusterPolicies.

Takeaways:
- New validation rules: write them as ValidatingPolicy in CEL.
- Simple, self-contained rules can run as native VAPs: faster, no
  availability dependency on Kyverno.
