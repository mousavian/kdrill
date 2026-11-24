Local rate limits are part of BackendTrafficPolicy:

    kubectl explain backendtrafficpolicy.spec.rateLimit.local.rules

Each rule has a `limit` (`requests` per `unit`: Second, Minute, Hour) and
optional `clientSelectors` (headers, source CIDR, methods, path) that
decide which requests the rule's bucket counts.
---
    rateLimit:
      type: Local
      local:
        rules:
        - clientSelectors:
          - headers: [{name: x-plan, value: gold}]
          limit: {requests: 30, unit: Minute}
        - limit: {requests: 5, unit: Minute}

Attach it with `targetRefs` to the HTTPRoute `api`.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
