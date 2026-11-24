Status first:

    kubectl describe httproute storefront
    kubectl -n infra get gateway public -o yaml

The route's parent status says `NotAllowedByListeners`, and after that
`RefNotPermitted`. Two separate problems: who may attach to the listener,
and who may point at a Service in another namespace.
---
1. In the Gateway, under the listener:

       allowedRoutes:
         namespaces:
           from: Selector
           selector: {matchLabels: {gateway-access: public}}

   then `kubectl label ns lab gateway-access=public`.
2. A `ReferenceGrant` in namespace `reviews`: `from` HTTPRoute in namespace
   `lab` (group `gateway.networking.k8s.io`), `to` Service (group `""`).
   `kubectl explain referencegrant.spec`
---
From the lesson directory:

    kubectl apply -f solution/gateway.yaml -f solution/referencegrant.yaml
    kubectl label ns lab gateway-access=public
