# CEL policies: rewrite a rule as a ValidatingPolicy, run it as a native VAP

## Concept

Kubernetes now has built-in policy: **ValidatingAdmissionPolicy (VAP)**,
GA since 1.30, evaluates **CEL** expressions inside the API server, with no
webhook. Kyverno followed. Besides the classic `ClusterPolicy` it ships
CEL-based types in `policies.kyverno.io`: **ValidatingPolicy**,
MutatingPolicy, GeneratingPolicy, ImageValidatingPolicy and DeletingPolicy.
In Kyverno 1.19 they are `v1`, and ClusterPolicy prints a deprecation
warning pointing to them.

A ValidatingPolicy looks like a VAP with extras:

    apiVersion: policies.kyverno.io/v1
    kind: ValidatingPolicy
    spec:
      validationActions: [Deny]        # or Audit, Warn
      matchConstraints:
        resourceRules:
        - {apiGroups: [""], apiVersions: [v1], operations: [CREATE, UPDATE], resources: [pods]}
      variables:
      - name: names
        expression: "object.spec.containers.map(c, c.name)"
      validations:
      - expression: "object.spec.containers.all(c, has(c.resources.limits))"
        messageExpression: "'missing limits in ' + variables.names.join(', ')"

CEL basics: `object` (and `oldObject`, `request`, `namespaceObject`), field
access with `has()` for optional fields, list macros `all`, `exists`,
`filter`, `map`, plus `size`, `in` and the ternary `a ? b : c`.

What Kyverno adds on top of a plain VAP: background scans and reports,
autogen for Pod controllers, PolicyExceptions, and CEL libraries for HTTP
calls, resource lookups and image data. And it can **generate a native VAP**
from a ValidatingPolicy (`spec.autogen.validatingAdmissionPolicy.enabled`).
The API server then enforces it directly, which is faster and keeps working
if Kyverno is down. That only works for policies a VAP can express (no
Kyverno-only libraries, no Pod-controller autogen).

Most clusters still run ClusterPolicies, so you need both: read and fix
the classic kind, write new rules in CEL.

## The situation

In `ml-serving`, the ClusterPolicy `require-limits` enforces memory limits on
containers and initContainers. A colleague started the CEL replacement, the
ValidatingPolicy `require-memory-limits`, but it only audits, ignores
initContainers and Deployments, and runs in Kyverno's webhook.

## Your task

Finish the migration:

- ValidatingPolicy `require-memory-limits` (`policies.kyverno.io/v1`) with
  `validationActions: [Deny]` rejects, in namespace `ml-serving` only,
  Pods **and** Deployments in which any container or initContainer has no
  memory limit, with a message containing
  `every container needs a memory limit: <names of those containers>`;
- Kyverno generates a ValidatingAdmissionPolicy from it
  (`vpol-require-memory-limits`), and the rejections come from that VAP;
- the ClusterPolicy `require-limits` is deleted.

Compliant Pods and Deployments (like `ranker`) are still admitted, and Pods
in other namespaces are not affected (verify uses `kyv-probe-other`).

## Useful commands

    kubectl get validatingpolicy require-memory-limits -o yaml
    kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
    kubectl explain validatingpolicy.spec --api-version=policies.kyverno.io/v1
    kubectl create --dry-run=server -f probes/pod-init-no-limit.yaml -n ml-serving

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/validating-policy/
- https://kyverno.io/docs/guides/migration-to-cel/
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/
