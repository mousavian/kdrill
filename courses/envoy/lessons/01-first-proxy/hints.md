Start with why Envoy is down:

    kubectl get pods -l app=envoy
    kubectl logs deploy/envoy

The last lines name the problem: a route refers to a cluster `echo`, and
`static_resources.clusters` is empty. Envoy refuses a config with dangling
references and exits.
---
A cluster needs a `name`, a discovery `type` and the endpoints. For a
Kubernetes Service, `type: STRICT_DNS` with a `load_assignment` whose
`socket_address` is `{address: echo, port_value: 80}` works: Envoy resolves
the name with the pod's DNS settings and re-resolves it every 5 s.

Edit with `kubectl edit configmap envoy`, then
`kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy`.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy
    kubectl rollout status deploy/envoy
    kubectl exec client -- hits http://envoy:10000/
