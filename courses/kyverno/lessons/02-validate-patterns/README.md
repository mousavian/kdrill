# Validate patterns: tags, registries, resources

## Concept

A validate rule says what's allowed in one of three ways.

**pattern**: the shape a valid object must have. Values support wildcards
(`*`, `?`), negation (`!`), comparisons for numbers and quantities
(`>=1Gi`), and combinations (`a | b`, `a & b`). Lists of objects are checked
element by element: every container must match. **Anchors** change how a
key is treated:

| Anchor | Meaning |
|---|---|
| `=(key)` | equality: if `key` is present, it must match |
| `(key)` | conditional: if `key` matches, check the rest of this element |
| `X(key)` | negation: `key` must not be present |
| `^(key)` | global: if this matches, apply the rule at all |

A pattern only checks the fields it mentions. Forget `initContainers` and
they are never checked.

**anyPattern**: a list of patterns; the object passes if any one matches.

**deny**: conditions that, when true, refuse the request. Keys and values
are **variables** in `{{ }}`, which are JMESPath expressions over the
admission request (`request.object`, `request.operation`,
`request.userInfo`, ...). Operators include `Equals`, `NotEquals`,
`AnyIn`, `AllNotIn`, `AnyNotIn`, `GreaterThan` and `DurationLessThan`.
Wildcards work in `AnyIn`-style values.

Variables also work in the `message`, so a rejection can name the exact
offending image or field:

    message: "bad images: {{ request.object.spec.containers[].image }}"

A policy can have many rules. Each rule is evaluated on its own, and the
rejection lists every failed rule.

## The situation

The Enforce ClusterPolicy `pod-standards` has a working `require-resources`
rule, a `disallow-latest` rule that misses initContainers and untagged
images, and no registry rule yet. Team `ml-serving` runs a compliant
`ranker` Deployment that must stay deployable.

## Your task

Fix `pod-standards` (keep the name). All three rules use Enforce:

- `require-resources`: unchanged behaviour (a container without a memory
  limit is still rejected).
- `disallow-latest`: images tagged `:latest` *and* images with no tag are
  rejected, in containers **and** initContainers, with the message
  `use a pinned image tag, not latest or no tag`.
- `restrict-registries` (new): any container or initContainer image not
  under `registry.acme.io/` or `ghcr.io/acme/` is rejected; the message
  contains `not from an approved registry` **and the offending image name(s)**.

Compliant Pods (and a copy of the `ranker` Deployment) must still be
admitted, and `ranker` stays at 2 ready replicas. verify dry-runs every file
in `probes/`.

## Useful commands

    kubectl get clusterpolicy pod-standards -o yaml
    kubectl create --dry-run=server -f probes/init-latest.yaml
    kubectl explain clusterpolicy.spec.rules.validate.deny.conditions
    kubectl -n ml-serving describe deploy ranker

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/validate/
- https://kyverno.io/docs/policy-types/cluster-policy/variables/
- https://kyverno.io/docs/policy-types/cluster-policy/jmespath/
- https://kyverno.io/docs/policy-types/cluster-policy/preconditions/
