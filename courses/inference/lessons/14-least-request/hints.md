    kubectl exec client -- ask -n 120 -c 12 -t 6 -w 10 http://edge/v1/chat/completions   # who answers how many? (pod names)
    kubectl get backendtrafficpolicy balance -o yaml
    kubectl explain backendtrafficpolicy.spec.loadBalancer

With round-robin every replica gets the same number of requests, however long they take. A slow replica holds
more and more concurrent requests (they pile up) while the fast ones are idle.
---
Change `spec.loadBalancer.type` from `RoundRobin` to `LeastRequest` in the BackendTrafficPolicy `balance`.
The new cluster configuration reaches Envoy in a few seconds.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
