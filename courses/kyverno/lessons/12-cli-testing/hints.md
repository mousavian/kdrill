Run the suite and see that it passes, although the policy has a bug:

    cd <workspace from kdrill start>       # default ~/.kdrill/work/kyverno-12
    ~/.kdrill/bin/kyverno test .

`kyverno-test.yaml` lists the expected `result` per policy, rule and
resource; `resources.yaml` holds the test Pods.
---
Add a Pod `gpu-sidecar-missing` to `resources.yaml` (an envoy container
first, then a container with `limits: {nvidia.com/gpu: 1}`, no nodeSelector)
and a results entry `result: fail` for it. The test now fails with
`Want fail, got skip`: the precondition only looks at `containers[0]`.
Fix it with `containers[]` and `length(@)`, the same JMESPath as lesson 04.
---
    cp solution/workspace/* ~/.kdrill/work/kyverno-12/     # from the lesson directory
    (cd ~/.kdrill/work/kyverno-12 && ~/.kdrill/bin/kyverno test .)
    kubectl apply -f ~/.kdrill/work/kyverno-12/policy.yaml
