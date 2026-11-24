See what the policy does to a Pod, without creating it:

    kubectl create --dry-run=server -f probes/cpu-pod.yaml -o yaml | grep -A12 tolerations
    kubectl create --dry-run=server -f probes/gpu-pod.yaml -o yaml | grep -A12 tolerations
    kubectl get pods -n ml-team -o wide

Three problems: it mutates every Pod, it *replaces* the tolerations list,
and it overwrites a GPU type the Pod chose.
---
- Only GPU Pods: a `preconditions` entry with key
  `{{ request.object.spec.containers[].resources.limits."nvidia.com/gpu" || `[]` | length(@) }}`,
  operator `GreaterThan`, value `0`.
- Appending: `patchesJson6902` with `op: add`, `path: /spec/tolerations/-`.
  Guard it with a second precondition so it doesn't add a duplicate
  (`request.object.spec.tolerations[?key == 'nvidia.com/gpu']` must be empty).
- Default only if absent: `nodeSelector: {+(nvidia.com/gpu.product): NVIDIA-L4}`.
A rule has one kind of patch, so use two rules.
---
    kubectl apply -f solution/policy.yaml          # from the lesson directory
    kubectl -n ml-team rollout restart deploy web chat trainer

Existing Pods only change when they are re-created.
