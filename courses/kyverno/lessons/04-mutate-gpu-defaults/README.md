# Mutate: GPU scheduling defaults

## Concept

A **mutate** rule changes a request before it is stored. Kyverno answers
the admission review with a patch, so the object that lands in etcd already
has the change. Typical uses: defaults (labels, securityContext, resources),
and scheduling hints such as tolerations and nodeSelectors.

Two patch styles:

- **patchStrategicMerge**: an overlay in the object's own shape. Maps
  merge, and lists with a merge key (containers by `name`) merge element by
  element. Lists *without* a merge key, like `tolerations`, are
  **replaced**. Anchors refine it: `+(key): value` adds the key only if it is
  absent, and `(key): value` is a condition ("only where key matches").
- **patchesJson6902**: RFC 6902 operations (`add`, `replace`, `remove`) on
  paths. `path: /spec/tolerations/-` appends to a list. `add` on an existing
  map path replaces the whole map.

**Preconditions** gate a rule with conditions over the request, e.g. "some
container requests a GPU". They use the same `{{ JMESPath }}` variables and
operators as deny conditions.

Mutations are not idempotent by themselves. An append runs every time the
webhook is called, and Kubernetes may call mutating webhooks again
(reinvocation) after other mutations. Guard appends with a precondition
that the change isn't already there.

Mutations only happen on create and update. A Pod that already runs keeps
whatever it got when it was created, so after fixing a mutate policy,
re-create the Pods (`kubectl rollout restart`). Kyverno also checks that
mutated objects still pass validation, so mutate before you validate.

On GPU clusters, mutation is how a platform team saves every user from
remembering the GPU node taint, the right node labels, or a priority
class.

## The situation

Fake nodes: two CPU workers; `l4-1` (4 × L4) and `h100-1` (8 × H100), both
tainted `nvidia.com/gpu=present:NoSchedule`, and `h100-1` is also tainted
`dedicated=training:NoSchedule`. The first version of ClusterPolicy
`gpu-defaults` (for namespace `ml-team`) adds the GPU toleration and an L4
nodeSelector to *every* Pod: `web` landed on the L4 node, and `trainer`
(which asks for H100s and tolerates `dedicated=training`) is Pending.

## Your task

Fix `gpu-defaults` (keep the name; any number of rules) so that, for Pods in
`ml-team`:

- a Pod where **any** container has a `nvidia.com/gpu` limit gets the
  toleration `{key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}`
  **appended**: its own tolerations are kept, and it is not added twice if
  the Pod already tolerates `nvidia.com/gpu`;
- such a Pod gets `nodeSelector: nvidia.com/gpu.product: NVIDIA-L4` only if
  it doesn't set `nvidia.com/gpu.product` itself; other nodeSelector keys
  are kept;
- Pods without GPUs are not touched.

Then get the workloads placed: `web` 2 ready on CPU workers, `chat` 2 ready
on `l4-1`, `trainer` 1 ready on `h100-1`. Don't edit the Deployments' specs
(only restart them); don't change the nodes.

verify dry-runs the Pods in `probes/` and reads back the mutated result.

## Useful commands

    kubectl create --dry-run=server -f probes/gpu-pod.yaml -o yaml
    kubectl get pods -n ml-team -o wide
    kubectl get nodes -L nvidia.com/gpu.product
    kubectl explain clusterpolicy.spec.rules.mutate
    kubectl -n ml-team rollout restart deploy web chat trainer

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/mutate/
- https://kyverno.io/docs/policy-types/cluster-policy/preconditions/
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
