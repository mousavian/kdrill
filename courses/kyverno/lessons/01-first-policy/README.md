# How Kyverno works: your first policy, Audit vs Enforce

## Concept

Kyverno is a policy engine that runs as a Kubernetes **admission webhook**.
Every create, update or delete that reaches the API server passes through
admission before it is stored. Kyverno registers webhooks for the kinds its
policies mention, receives each matching request, runs the policies and
answers "allowed", "allowed with changes" (mutate) or "denied, because ...".

A **ClusterPolicy** (cluster-wide; a `Policy` is the namespaced variant) is
a list of **rules**. Each rule has:

- `match` (and optionally `exclude`): which requests the rule applies to,
  e.g. `kinds: [Pod]`.
- one action: `validate`, `mutate`, `generate` or `verifyImages`.

A validate rule with a **pattern** describes what a valid object looks like,
in the object's own YAML shape:

    validate:
      failureAction: Enforce
      message: "every Pod needs a team label"
      pattern:
        metadata:
          labels:
            team: "?*"

Wildcards in values: `*` matches anything (including the empty string),
`?` exactly one character, so `?*` means "at least one character".

`failureAction` decides what a violation does:

- **Audit** (the default): the request is allowed. The violation is written
  to a PolicyReport (lesson 09); the user sees nothing unless the policy
  sets `spec.emitWarning: true`, which makes kubectl print a warning.
- **Enforce**: the request is rejected with the rule's message.

The usual rollout is Audit first, read the reports and fix the offenders,
then Enforce. Note that admission only judges *requests*. Objects stored
before the policy existed are not touched, but their next update or the
next Pod a controller creates for them is checked.

You'll see a warning that `kyverno.io/v1 ClusterPolicy is deprecated`. That
is Kyverno 1.19 nudging toward its newer CEL-based policy types (lesson 11).
ClusterPolicy still works fully and is what most clusters run today.

## The situation

Kyverno runs in namespace `kyverno`. The platform team's ClusterPolicy
`require-team-label` is supposed to make every Pod carry a `team` label, but
it only audits, its message is useless, and it lets `team: ""` through. The
Deployment `web` (2 replicas) in `shop` has no team label at all.

## Your task

Fix the policy `require-team-label` (keep its name and its rule `check-team`):

- rule `check-team` uses `failureAction: Enforce`;
- a Pod without a `team` label, or with an empty one, is rejected with a
  message containing exactly `every Pod needs a non-empty team label`;
- a Pod with a non-empty `team` label is admitted.

Then make `web` compliant: its Pod template has a non-empty `team` label,
it still asks for 2 replicas, both are ready, and every `web` Pod carries
the label.

`kdrill verify` tests the policy by server-side dry-run of the manifests in
`probes/` (Pods without, with empty and with a `team` label).

## Useful commands

    kubectl get clusterpolicy                       # READY column, ADMISSION/BACKGROUND
    kubectl get clusterpolicy require-team-label -o yaml
    kubectl explain clusterpolicy.spec.rules.validate
    kubectl -n shop run t --image=nginx --dry-run=server              # try it
    kubectl -n shop run t --image=nginx --labels=team= --dry-run=server
    kubectl -n kyverno get pods

When you think you're done: `kdrill verify`

## On a real cluster

Here every Kyverno webhook is installed with `failurePolicy: Ignore`
(Kyverno's `forceFailurePolicyIgnore` flag), so a stopped Kyverno can never
block the lab cluster. Production installs usually run several replicas and
let Enforce policies fail closed (`failurePolicy: Fail`). This course's
cleanup also deletes *all* Kyverno policies, exceptions and cluster reports
when a lesson ends.

## Read more

- https://kyverno.io/docs/introduction/how-kyverno-works/
- https://kyverno.io/docs/policy-types/cluster-policy/validate/
- https://kyverno.io/docs/policy-types/cluster-policy/validate/#patterns
- https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
