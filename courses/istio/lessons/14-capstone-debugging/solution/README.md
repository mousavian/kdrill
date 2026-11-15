# Solution

    kubectl apply -f solution/services.yaml -f solution/mesh.yaml -f solution/gateway.yaml

| # | Symptom | Bug | Fix |
|---|---|---|---|
| 1 | `/pay/...` via gateway: 500 | backendRef `payments` port 80; the Service only has 8000 | port 8000 (`gateway.yaml`) |
| 2 | `x-beta` routing ignored, random v1/v2 | catalog's port named `tcp-web`: opaque TCP, so the VirtualService's HTTP routes never apply | `http-web` (`services.yaml`) |
| 3 | `web -> payments`: 503 `upstream connect error ... reset`; gateway too | DestinationRule `payments` sets `tls.mode: DISABLE`, so callers send plaintext to a STRICT server | remove `tls` (auto mTLS) (`mesh.yaml`) |
| 4 | `/pay/...` via gateway: 403 `RBAC: access denied` (after 1 and 3) | policy allows `sa/shop-gateway`; the automatically deployed gateway runs as `sa/shop-gateway-istio` | correct principal (`mesh.yaml`) |

How to find each one (none of them makes a resource invalid, so
`istioctl analyze` and the route status stay quiet):

1. The gateway itself answers 500 for `/pay/`. Istio accepts the route
   (`ResolvedRefs: True`; it does not check ports), so compare the
   backendRef with `kubectl -n shop get svc payments`: port 8000, not 80.
2. `istioctl proxy-config listeners deploy/web -n shop --port 8000` shows a
   separate TCP proxy listener for catalog's ClusterIP instead of the
   shared HTTP `0.0.0.0_8000` listener, and `proxy-config routes` has no
   virtual host for catalog.
3. `istioctl proxy-config clusters deploy/web -n shop --fqdn
   payments.shop.svc.cluster.local -o json` shows the
   `envoy.transport_sockets.raw_buffer` (plaintext) socket instead of
   `envoy.transport_sockets.tls`, while `istioctl x describe pod` on
   payments says STRICT. The reset comes from payments' sidecar, which only
   accepts mTLS. `scanner` got the same 503 instead of its 403.
4. `istioctl x authz check deploy/payments -n shop` lists the principals;
   the gateway Pod's `serviceAccountName` is `shop-gateway-istio`.

Bugs 1, 3 and 4 hide behind each other on the `/pay/` path: fixing one
reveals the next. That is normal; always re-test the full path.

Takeaways:
- Run `istioctl analyze` and read route status first, but a clean result
  proves nothing: compare what you meant with what `proxy-config` shows.
- Protocol and TLS mode are decided on the client side; STRICT and
  authorization on the server side.
- Never "fix" by weakening STRICT or deleting the AuthorizationPolicy.
