# Background scans and PolicyReports: find existing violations

## Concept

Admission only sees new requests. To find out what's *already* running
against your rules, Kyverno does **background scans**. For every policy with
`background: true` (the default), the **reports controller** evaluates the
matching stored objects: when the policy changes, when an object changes,
and periodically. It records the outcome in **PolicyReports**, the
Kubernetes policy working group's report format (`wgpolicyk8s.io`):

- one `PolicyReport` per resource, in the resource's namespace, named
  after its UID (`ClusterPolicyReport` for cluster-scoped resources);
- `.scope` points at the resource; `.summary` counts pass, fail, warn,
  error and skip;
- `.results[]` has one entry per policy rule: `policy`, `rule`, `result`,
  `message`.

    kubectl get polr -A -o wide          # short name polr; cpolr for cluster reports
    kubectl -n team-a get polr <name> -o yaml

Audit rules report violations without blocking; Enforce rules block new
requests *and* still report on objects that existed before. Because of
autogen, a Deployment, its ReplicaSets and its Pods each get results. Old
ReplicaSets from earlier rollouts keep failing results until they're
garbage-collected.

That gives the standard rollout for a new rule:

1. Apply it in **Audit** with background scanning.
2. Read the reports, fix workloads (or grant exceptions, next lesson).
3. Switch to **Enforce** when the reports are clean.

Rules that depend on who made the request (`subjects`, `request.userInfo`)
can't be background-scanned (lesson 03), and neither can most rules that
look at `request.operation` or `request.oldObject`.

## The situation

Six Deployments run in `team-a` and `team-b`. The platform team added the
ClusterPolicy `best-practices` (memory limits, pinned image tags) in Audit
mode, but with `background: false`, so `kubectl get polr -A` shows nothing and
nobody knows who is affected.

## Your task

- Turn on background scanning for `best-practices` (keep its name, rules and
  messages).
- Use the PolicyReports to find the Deployments that fail, and fix those
  Deployments (pin a tag, add a memory limit) until no Deployment or Pod in
  `team-a`/`team-b` has a failing result for `best-practices`. All six
  Deployments keep running (1 ready replica each).
- Then switch both rules to `Enforce`: a `:latest` Pod (team-a) and a Pod
  without a memory limit (team-b) are rejected, a compliant Pod is admitted.

## Useful commands

    kubectl get polr -A -o wide
    kubectl -n team-a get polr -o yaml | grep -B2 -A6 'result: fail'
    kubectl -n team-a set image deploy/worker worker=registry.acme.io/worker:3.7.2
    kubectl -n team-a edit deploy cache

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/guides/reports/
- https://kyverno.io/docs/policy-types/cluster-policy/policy-settings/
- https://kyverno.io/docs/guides/applying-policies/
