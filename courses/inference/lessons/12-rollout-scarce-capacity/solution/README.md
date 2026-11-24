# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml
    kubectl apply -f solution/pdb.yaml
    kubectl rollout status deploy/llm --timeout=90s

    strategy: {type: RollingUpdate, rollingUpdate: {maxSurge: 0, maxUnavailable: 1}}
    minReadySeconds: 5
    PodDisruptionBudget: minAvailable: 3

The default rolling update is "surge first": start a new pod, wait until it is ready, then
stop an old one, so capacity never dips. That needs *spare capacity for one more
pod*. Here the quota (standing in for "no free GPU": a model server holds a whole GPU)
has none, so the new pod was never created and the rollout hung with four healthy old
pods. `maxSurge: 0, maxUnavailable: 1` flips it: stop one old pod, start its
replacement in the freed slot, wait, repeat. Capacity dips to 3 of 4 for the duration
(the price of not having a spare GPU) and never lower, because only one is replaced
at a time.

`minReadySeconds: 5` makes a new pod count as available only after 5 s of being
ready, so the next old pod is not stopped on the strength of a single successful probe
(a model that is "ready" but crashes on its first request would otherwise take the whole
fleet down, one replica at a time).

The PodDisruptionBudget covers a different actor: the Deployment controller respects
`maxUnavailable` itself, but a node drain or the cluster autoscaler evicts pods through
the eviction API, and only a PDB limits that. `minAvailable: 3` guarantees that
voluntary disruption never takes more than one of four replicas at a time.

Lesson 24 does the same dance on fake GPU nodes.
