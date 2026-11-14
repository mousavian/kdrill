Read the status Envoy Gateway writes back:

    kubectl get gatewayclass
    kubectl get gateway edge
    kubectl describe gateway edge
    kubectl get httproute web -o yaml | sed -n '/^status:/,$p'

A Gateway that names a GatewayClass nobody owns is simply ignored: no
status, no Envoy. And a route only attaches to a Gateway its `parentRefs`
name.
---
- Gateway: `gatewayClassName: eg`.
- HTTPRoute web: `parentRefs: [{name: edge}]`.
- A new HTTPRoute `api`: `parentRefs: [{name: edge}]`, `hostnames: ["api.lab"]`,
  `rules: [{backendRefs: [{name: api, port: 80}]}]`.

Once the Gateway is accepted, `kubectl get pods,svc` shows the Envoy pod
and Service `edge` that Envoy Gateway created.
---
    kubectl apply -f solution/edge.yaml      # from the lesson directory
    kubectl get gateway edge -w              # until PROGRAMMED is True
    kubectl exec client -- hits http://edge/ -H 'Host: www.lab'
