# Solution

**db** needs a hard rule. The simplest is a `nodeSelector` (always a hard,
exact-match requirement):

    kubectl patch deploy db --type merge \
      -p '{"spec":{"template":{"spec":{"nodeSelector":{"disktype":"ssd"}}}}}'

An equivalent is `requiredDuringSchedulingIgnoredDuringExecution` node affinity
with `matchExpressions: [{key: disktype, operator: In, values: [ssd]}]`.
Use that form when you need more than equality (`In` with several values,
`NotIn`, `Exists`, `Gt`/`Lt`).

**cache** should *prefer* zone a but still run elsewhere if zone a is full or
down, so it gets a soft rule. `solution/cache.yaml` is the full Deployment:

    kubectl apply -f solution/cache.yaml

(Run from the lesson directory; the Deployment uses `Recreate`, same as the
starting manifest.)

Takeaways:
- `required…` filters nodes: no match means the pod stays Pending.
- `preferred…` only adds to a node's score: the scheduler tries, but may ignore it.
- Both are evaluated at scheduling time; "IgnoredDuringExecution" means pods
  already running are not moved if node labels change later.
- Don't fix placement by relabelling nodes — labels should describe reality.
