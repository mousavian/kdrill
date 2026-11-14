# Solution

The fixed files are in `solution/workspace/`. From the lesson directory:

    WS=~/.kdrill/work/kyverno-12            # (or wherever setup said)
    cp solution/workspace/* "$WS"/
    cd "$WS" && ~/.kdrill/bin/kyverno test .
    kubectl apply -f "$WS/policy.yaml"

The order a policy author would work in:

1. Write the failing case first: add `gpu-sidecar-missing` (proxy first,
   GPU in the second container, no nodeSelector) to `resources.yaml` and a
   results entry `result: fail` to `kyverno-test.yaml`.
   `kyverno test .` now fails: `Want fail, got skip`. The precondition only
   looked at `containers[0]`, so the rule never applied.
2. Fix the precondition to look at every container:
   `{{ request.object.spec.containers[].resources.limits."nvidia.com/gpu" || `[]` | length(@) }}`
   `GreaterThan 0`.
3. `kyverno test .` passes, so apply the policy to the cluster.

Result values: `pass` (rule applied, resource OK), `fail` (violation),
`skip` (rule didn't apply: match, exclude or preconditions said no), `warn`,
`error`.

In CI: run `kyverno test` on every policy change (it exits non-zero on a
failed expectation), and `kyverno apply policy.yaml --resource ...` over your
rendered manifests (Helm/Kustomize output) to catch violations before they
reach a cluster. `kyverno apply ... --cluster` evaluates a policy against
live resources without installing it.

Takeaways:
- Every bug in a policy is a missing test case; add the case first.
- Test skip as well as pass and fail: skip results catch over-narrow
  matches and preconditions.
