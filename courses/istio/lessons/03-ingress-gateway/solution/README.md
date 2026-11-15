# Solution

    kubectl apply -f solution/gateway.yaml        # from the lesson directory

`solution/gateway.yaml` holds:

- `Gateway shop-gateway`: class `istio`, listener `http` on port 80 for
  `shop.example.com`, routes only from its own namespace, and the
  annotation `networking.istio.io/service-type: ClusterIP`. istiod creates
  `deploy/shop-gateway-istio` and `svc/shop-gateway-istio` and sets
  `Programmed=True` once the Service has an address.
- `HTTPRoute shop`: rule 1 matches `PathPrefix /api/`, rewrites the prefix
  to `/` (`URLRewrite` / `ReplacePrefixMatch`) and sends it to `api:8000`;
  rule 2 sends `PathPrefix /` to `web:8000`. The longer prefix wins.

Requests for other hosts reach the gateway but match no virtual host, so
Envoy answers 404 itself.

What the gateway's Envoy got (`istioctl proxy-config routes
deploy/shop-gateway-istio -n shop`): a route table `http.80` with a
virtual host `shop.example.com:80` and two routes, `/api/` with a
`prefix_rewrite` to `/` and `/`.

Takeaways:
- Gateway = where traffic enters (listeners), HTTPRoute = what happens to it.
- Check `Programmed` on the Gateway and `Accepted`/`ResolvedRefs` on routes
  before debugging traffic.
- With automated deployment, deleting the Gateway deletes its Envoy too.
