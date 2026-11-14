# Solution

All six pods are in zone a because the pod template has
`nodeSelector: topology.kubernetes.io/zone: a`. Removing it frees the scheduler
to use every zone, but without further instructions it only spreads pods on a
best-effort basis. A **topology spread constraint** makes the even spread a rule:

    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels: {app: api}

Apply it (and drop the nodeSelector) with `kubectl edit deploy api`, or from the
lesson directory:

    kubectl apply -f solution/api.yaml

How to read it: for each zone the scheduler counts pods matching
`labelSelector`; placing a pod must keep (max count − min count) ≤ `maxSkew`.
With 6 pods in 3 zones and maxSkew 1 the only stable result is 2/2/2.
`DoNotSchedule` leaves a pod Pending rather than violating the rule;
`ScheduleAnyway` would just treat skew as a scoring preference.

Takeaways:
- `topologyKey` is any node label; zone, hostname and region are the common ones.
- The `labelSelector` must match the pods you want counted (usually the Deployment's own labels).
- Spreading is evaluated at scheduling time; it does not rebalance running pods
  (here a rollout creates new pods, so it applies).
