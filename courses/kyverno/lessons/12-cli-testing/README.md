# Test policies offline with the kyverno CLI

## Concept

A policy is code, and a broken one either blocks deploys or silently lets
everything through. The **kyverno CLI** runs the same engine as the
admission controller, without a cluster:

- `kyverno apply policy.yaml --resource pod.yaml` shows what the policy does
  to given resources (validate results, mutated output). With `--cluster` it
  evaluates against live resources without installing the policy.
- `kyverno test <dir>` runs **test suites**: a `kyverno-test.yaml` names
  policies, resources and the expected result per policy/rule/resource:

      apiVersion: cli.kyverno.io/v1alpha1
      kind: Test
      metadata: {name: my-tests}
      policies: [policy.yaml]
      resources: [resources.yaml]
      results:
      - policy: gpu-product-required
        rule: require-gpu-product
        kind: Pod
        resources: [gpu-pod-missing]
        result: fail          # pass | fail | skip | warn | error

  It exits non-zero when an expectation isn't met, so it drops straight
  into CI. Suites can also check mutated output (`patchedResources`),
  generated resources, and supply `values` for context variables and
  `userInfo`.
- `kyverno jp query` evaluates JMESPath expressions, which helps when writing
  conditions.

`skip` means the rule didn't apply (match, exclude or a precondition said
no). Testing for skip catches rules that are too narrow, which is the
dangerous kind of bug because nothing fails visibly.

The CLI's version should match the cluster's Kyverno. kdrill downloads the
pinned `kyverno` v1.19 binary into its state directory (checksum-verified,
nothing installed system-wide).

## The situation

`kdrill start` printed two paths: the CLI (default `~/.kdrill/bin/kyverno`)
and your workspace (default `~/.kdrill/work/kyverno-12`), with a policy
`gpu-product-required` ("GPU Pods must set `nodeSelector
nvidia.com/gpu.product`"), three test Pods and a suite that passes. But a
Pod whose GPU is requested by its second container (e.g. behind a proxy
sidecar) gets through. The policy isn't applied to the cluster yet.

## Your task

In the workspace:

- add a Pod named `gpu-sidecar-missing` (namespace `ml`; first container
  without GPU, second with `limits: nvidia.com/gpu: 1`, no nodeSelector) to
  `resources.yaml`, and a results entry for it expecting `fail` to
  `kyverno-test.yaml`;
- fix `policy.yaml` (keep the policy name `gpu-product-required`, rule
  `require-gpu-product` and message) so that `kyverno test .` passes;
- apply it to the cluster: in `ml`, a GPU Pod without
  `nvidia.com/gpu.product` is rejected wherever the GPU is requested; a GPU
  Pod with it is admitted.

verify also runs **kdrill's reference suite** in the lesson's `tests/`
directory against your `policy.yaml` (more GPU/CPU cases: empty product,
sidecars, CPU Pods with other selectors). `kdrill reset` restores the
workspace and discards your edits.

## Useful commands

    ~/.kdrill/bin/kyverno test ~/.kdrill/work/kyverno-12
    ~/.kdrill/bin/kyverno apply ~/.kdrill/work/kyverno-12/policy.yaml --resource ~/.kdrill/work/kyverno-12/resources.yaml
    echo '{"a":[{"b":1},{"c":2}]}' | ~/.kdrill/bin/kyverno jp query 'a[].b || `[]` | length(@)'
    kubectl apply -f ~/.kdrill/work/kyverno-12/policy.yaml

(With a custom `KDRILL_STATE_DIR`, use the paths `kdrill start` printed.)

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/guides/testing-policies/
- https://kyverno.io/docs/kyverno-cli/reference/kyverno_test/
- https://kyverno.io/docs/kyverno-cli/reference/kyverno_apply/
