Istio registers a GatewayClass called `istio`. Creating a `Gateway` of that
class makes Istio deploy an Envoy Deployment and Service named
`<gateway>-istio` for you:

    kubectl get gatewayclass
    kubectl explain gateway.spec.listeners
    kubectl explain httproute.spec.rules

Remember the annotation `networking.istio.io/service-type: ClusterIP` on
the Gateway (no load balancer in this cluster).
---
Two rules in one HTTPRoute (`parentRefs: [{name: shop-gateway}]`,
`hostnames: [shop.example.com]`):

- match `PathPrefix /api/`, filter `URLRewrite` with
  `path: {type: ReplacePrefixMatch, replacePrefixMatch: /}`, backend `api` port 8000;
- match `PathPrefix /`, backend `web` port 8000.

The most specific match wins, whatever the order.
---
    kubectl apply -f solution/gateway.yaml        # from the lesson directory
    kubectl -n outside exec deploy/visitor -c curl -- \
      curl -s -H 'Host: shop.example.com' shop-gateway-istio.shop/api/hostname
