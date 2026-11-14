Timeouts are part of the Gateway API itself:

    rules:
    - matches: [...]
      timeouts:
        request: 1s

`kubectl explain httproute.spec.rules.timeouts`. Retries aren't in the
standard channel yet; Envoy Gateway has them in its BackendTrafficPolicy,
which you attach to a Gateway or route with `targetRefs`.
---
    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: BackendTrafficPolicy
    metadata: {name: api-retries}
    spec:
      targetRefs:
      - {group: gateway.networking.k8s.io, kind: HTTPRoute, name: api}
      retry:
        numRetries: 2
        retryOn:
          triggers: [connect-failure, retriable-status-codes]
          httpStatusCodes: [503]

Check `kubectl get backendtrafficpolicy api-retries -o yaml`: the status
says whether it was accepted, per Gateway.
---
    kubectl apply -f solution/routes.yaml      # from the lesson directory
