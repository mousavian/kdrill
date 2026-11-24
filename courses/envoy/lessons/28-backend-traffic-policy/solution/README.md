# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml

    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: BackendTrafficPolicy
    metadata: {name: cart-backend}
    spec:
      targetRefs:
      - {group: gateway.networking.k8s.io, kind: HTTPRoute, name: cart}
      loadBalancer:
        type: ConsistentHash
        consistentHash: {type: Header, header: {name: x-user}}
      healthCheck:
        passive:
          consecutive5XxErrors: 3
          interval: 2s
          baseEjectionTime: 30s
          maxEjectionPercent: 50

What Envoy Gateway generated (port-forward to `deploy/edge`,
`config_dump?resource=dynamic_active_clusters`): the cluster
`httproute/lab/cart/rule/0` with `lb_policy: MAGLEV` and
`outlier_detection` with your values, and a `hash_policy` on the route
with `header_name: x-user`. Lessons 05 and 07, written as intent.

Notes:
- Hashing and ejection interact: users whose hash landed on the sick pod
  got errors until it was ejected, then moved to another pod; after the
  ejection ends they may move back. Consistent hashing is affinity, not a
  guarantee.
- `healthCheck.active` adds Envoy's own probes (lesson 06);
  `circuitBreaker` sets the thresholds from lesson 10; `loadBalancer.type`
  also accepts `LeastRequest`, `Random`, `RoundRobin`, and
  `slowStart`/`zoneAware` options.
- One policy per target: a second BackendTrafficPolicy on the same route
  conflicts (the older one wins, the other reports `Conflicted`). A policy
  on the route overrides one on the Gateway unless `mergeType` is set.
