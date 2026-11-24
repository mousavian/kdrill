# Capstone: policies that don't do what they say

## Concept

A policy that is "Ready" isn't necessarily doing anything. Policy bugs
rarely produce errors: the rule just doesn't apply, or applies in the wrong
way. A debugging routine:

1. **Reproduce with a dry-run.** `kubectl create --dry-run=server -f x.yaml`
   runs the full admission chain without storing anything. Admitted means
   the rule didn't apply, passed, or failed in Audit mode (no warning unless
   the policy sets `emitWarning: true`; the PolicyReport shows the result).
2. **Did the rule match?** Compare `match`/`exclude` with the real object
   and its namespace (`kubectl get ns --show-labels`). A typo in a label key
   matches nothing, silently.
3. **What does the rule do?** `failureAction` (Audit only reports), the
   pattern semantics (`=( )` "if present", `( )` "if this matches", `X( )`
   "must not exist", `*` vs `?*`), and preconditions (a precondition that
   is false means `skip`).
4. **Controllers.** `status.autogen` and the
   `pod-policies.kyverno.io/autogen-controllers` annotation decide whether
   Deployments, Jobs and CronJobs are checked at apply time or only their
   Pods later (FailedCreate).
5. **Mutations.** Rules in a policy run top to bottom, each on the result
   of the previous one. Kyverno mutates before it validates. Only new
   objects get mutated, so restart workloads after a fix.
6. **Evidence.** PolicyReports (`kubectl get polr -A -o wide`), events on
   the resource and the controller (`kubectl describe rs`), Kyverno's logs
   (`kubectl -n kyverno logs deploy/kyverno-admission-controller`), and
   `kyverno apply`/`kyverno test` offline.

The fix almost always belongs in the policy: carving out exclusions or
hand-editing workloads to make a symptom go away leaves the bug in place
for everyone else.

## The situation

Namespaces `payments` and `analytics` are labelled `env=prod`; `playground`
is `env=dev`. There is a fake GPU node `gpu-1` (tainted
`nvidia.com/gpu=present:NoSchedule`). Four ClusterPolicies are documented in
comments at the top of each policy, and here:

1. `require-owner-label`: every Pod in an `env=prod` namespace has a
   non-empty `owner` label.
2. `restrict-registries`: in `env=prod` namespaces every container and
   initContainer image comes from `registry.acme.io/`.
3. `require-run-as-nonroot`: Pods in `env=prod` namespaces set
   `spec.securityContext.runAsNonRoot: true`, and Deployments, Jobs and
   CronJobs with such Pod templates are rejected when applied.
4. `gpu-tier`: GPU Pods (any container with a `nvidia.com/gpu` limit) get the
   label `scheduling.acme.io/tier=gpu`, and every Pod with that label gets
   the toleration `nvidia.com/gpu` (Exists, NoSchedule), once.

None of them works as described. The `fraud-model` GPU Deployment in
`payments` is Pending.

## Your task

Fix the four policies (keep their names, rule names and messages; no
`exclude` blocks) so that:

- `payments`: a Pod without `owner` is rejected (`Pods in prod namespaces need
  a non-empty owner label`), a Pod without `runAsNonRoot` is rejected (`Pods in
  prod namespaces must set runAsNonRoot`), and so are a Job and a CronJob with
  such a template, at apply time;
- `analytics`: a Pod with a `docker.io` image is rejected (`images must come
  from registry.acme.io`);
- a GPU Pod gets the tier label and exactly one GPU toleration; non-GPU Pods
  get no toleration;
- a compliant Pod in `payments` and an "anything goes" Pod in `playground`
  are admitted;
- `checkout` (2), `reports` (1) and `scratch` (1) stay ready, and
  `fraud-model` runs on `gpu-1`, without changing any workload's spec (you
  may restart them).

verify dry-runs the files in `probes/`.

## Useful commands

    kubectl get clusterpolicy
    kubectl get ns --show-labels
    kubectl create --dry-run=server -f probes/pod-gpu.yaml -n payments -o yaml | grep -A8 -e labels: -e tolerations:
    kubectl get clusterpolicy require-run-as-nonroot -o jsonpath='{.status.autogen}'
    kubectl get polr -A -o wide
    kubectl -n payments describe pod -l app=fraud-model

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/guides/troubleshooting/
- https://kyverno.io/docs/policy-types/cluster-policy/validate/#anchors
- https://kyverno.io/docs/policy-types/cluster-policy/mutate/
- https://kyverno.io/docs/policy-types/cluster-policy/autogen/
