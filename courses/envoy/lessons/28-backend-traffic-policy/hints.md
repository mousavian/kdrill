Both behaviours are fields of one BackendTrafficPolicy:

    kubectl explain backendtrafficpolicy.spec.loadBalancer
    kubectl explain backendtrafficpolicy.spec.healthCheck.passive

Attach it with `targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: cart}]`.
---
    loadBalancer:
      type: ConsistentHash
      consistentHash:
        type: Header
        header: {name: x-user}
    healthCheck:
      passive:
        consecutive5XxErrors: 3
        baseEjectionTime: 30s
        maxEjectionPercent: 50
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
