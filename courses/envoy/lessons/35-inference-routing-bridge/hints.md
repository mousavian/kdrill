The feature is part of BackendTrafficPolicy's load balancer:

    kubectl explain backendtrafficpolicy.spec.loadBalancer.endpointOverride

It needs a normal load balancer `type` as the fallback.
---
    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: BackendTrafficPolicy
    metadata: {name: llm-endpoint-picking}
    spec:
      targetRefs:
      - {group: gateway.networking.k8s.io, kind: HTTPRoute, name: llm}
      loadBalancer:
        type: LeastRequest
        endpointOverride:
          extractFrom:
          - header: x-gateway-destination-endpoint

Then try it with a pod IP from `kubectl get pods -l app=llama -o wide`.
The new cluster takes up to ~15 s to warm.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
