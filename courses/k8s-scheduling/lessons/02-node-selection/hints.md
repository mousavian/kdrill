Compare the node labels with `kubectl get nodes -L disktype,topology.kubernetes.io/zone`.
The scheduler only places pods by rules you put in the pod spec; right now `db` has none.
---
Two tools: `nodeSelector` (simple, always a hard rule, exact match) and
`affinity.nodeAffinity` (richer). Node affinity comes in two flavours:
`requiredDuringSchedulingIgnoredDuringExecution` (hard) and
`preferredDuringSchedulingIgnoredDuringExecution` (soft, with a weight).
`db` needs a hard rule; `cache` needs a soft one.
---
For db: `kubectl patch deploy db --type merge -p '{"spec":{"template":{"spec":{"nodeSelector":{"disktype":"ssd"}}}}}'`.
For cache: add under spec.template.spec
`affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` a list item with
`weight: 50` and `preference.matchExpressions: [{key: topology.kubernetes.io/zone, operator: In, values: ["a"]}]`
(`kubectl edit deploy cache`). The full manifests are in solution/.
