# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml
    kubectl -n ml-team rollout restart deploy web chat trainer

What was wrong with the first attempt, and the fix:

| Problem | Effect | Fix |
|---|---|---|
| no precondition | `web` got the GPU toleration and the L4 selector and sat on the GPU node | `preconditions`: some container has `limits."nvidia.com/gpu"` |
| strategic merge on `tolerations` | replaced the list: `trainer` lost `dedicated=training` (and the default not-ready/unreachable tolerations) | JSON patch `add /spec/tolerations/-` appends |
| plain `nvidia.com/gpu.product: NVIDIA-L4` | overwrote trainer's H100 choice | `+(nvidia.com/gpu.product)` adds only if absent |

The precondition JMESPath
`request.object.spec.containers[].resources.limits."nvidia.com/gpu" || \`[]\` | length(@)`
collects the GPU limits of all containers (keys with dots need quotes),
falls back to an empty list, and counts them.

The second precondition makes the append idempotent. Kyverno's webhook can be
called again (reinvocation) when other mutations change the Pod, and the
Pod may already tolerate the taint; a blind append would duplicate it.

Mutations happen only when an object is created or updated: the Pods that
already existed kept their old (wrong) mutations until the restart.

Gotcha for a "default priority class" rule: by the time Kyverno sees a Pod,
the API server has already set `spec.priority: 0`. Setting only
`priorityClassName` is then rejected ("the integer value of priority must
not be provided"). A JSON patch must also `remove /spec/priority`.

Takeaways:
- Strategic merge for maps and keyed lists (containers by name); JSON patch
  for appending to plain lists.
- Gate mutations with preconditions; make them idempotent.
- Mutations don't touch running Pods; restart them.
