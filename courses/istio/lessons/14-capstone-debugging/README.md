# Capstone: a mesh that doesn't do what it says

## Concept

Istio configuration rarely fails loudly. A resource is accepted, its
status looks fine, and the traffic just doesn't do what you meant. A
debugging routine that works for almost everything:

1. **Reproduce** from the right place: from a Pod in the mesh, from one
   outside it, through the gateway. Note the status code *and* who
   produced it: an Envoy-generated answer has a telling body
   (`no healthy upstream`, `upstream connect error ... reset`,
   `RBAC: access denied`, `fault filter abort`) and, in access logs, a
   response flag.
2. **Ask Istio**: `istioctl analyze -n <ns>` catches many mistakes (unknown
   hosts, missing subsets, conflicting policies). For the Gateway API, read
   `status.conditions` on Gateways and routes (`Accepted`, `ResolvedRefs`,
   `Programmed`). Both only see invalid or inconsistent resources; a
   valid resource that says the wrong thing passes them silently.
3. **Read what the proxy really got**: `istioctl proxy-config
   listeners|routes|clusters|endpoints <pod>` on the client side, and on
   the server side. Is there an HTTP route at all (protocol)? Does the
   cluster have endpoints (subsets, ports)? What TLS mode does the cluster
   use?
4. **Check policy** on the server: `istioctl x describe pod <pod>` (mTLS
   mode, matching policies), `istioctl x authz check <pod>`, the server
   sidecar's logs.
5. **Fix the config, not the symptom**. Turning off STRICT, deleting the
   AuthorizationPolicy or adding an "allow all" rule makes the error go
   away and the security with it.

Remember who decides what: the **client** sidecar applies VirtualService
routes, DestinationRule subsets, timeouts, retries and the TLS mode it
sends (auto mTLS unless a DestinationRule overrides it); the **server**
sidecar applies PeerAuthentication and AuthorizationPolicy; the gateway is
a client for the Services behind it.

## The situation

Namespace `shop` (in the mesh, PeerAuthentication STRICT):

- Gateway `shop-gateway` for `shop.example.com`, HTTPRoute `shop`:
  `/catalog/...` -> `catalog`, `/pay/...` -> `payments` (prefixes stripped).
- `catalog-v1` and `catalog-v2` behind Service `catalog`, with a
  DestinationRule and a VirtualService: `x-beta: true` -> v2, others -> v1.
- `payments`, with a DestinationRule (connection pool settings) and an
  AuthorizationPolicy allowing only the ingress gateway and `web`.
- curl clients `web` and `scanner`.

Namespace `outside`: the `visitor` curl Pod (no sidecar).

Symptoms: `/pay/...` through the gateway fails, beta users land on v1 half
the time (and everyone else on v2), and `web` can't call `payments`.

## Your task

Fix the configuration (Services, routes, DestinationRules, policies) so that:

- `shop.example.com/catalog/...` and `shop.example.com/pay/...` work through
  the gateway;
- from `web`, `x-beta: true` always reaches catalog-v2 and everything else
  catalog-v1;
- `web` reaches `payments` over mTLS;

while the security stays as designed: `shop` stays STRICT (a plaintext
client is rejected), `scanner` still gets 403 from payments, the
AuthorizationPolicy stays an ALLOW policy, and the workloads are unchanged.

## Useful commands

    istioctl analyze -n shop      # ignore IST0107 on the shop-gateway-istio objects: Istio copies the Gateway's annotation onto them
    kubectl -n shop get gateway,httproute,virtualservice,destinationrule,peerauthentication,authorizationpolicy
    istioctl proxy-config routes deploy/web -n shop --name 8000
    istioctl proxy-config clusters deploy/web -n shop --fqdn payments.shop.svc.cluster.local -o json | grep transport_sockets
    istioctl x describe pod -n shop <payments-pod>
    istioctl x authz check deploy/payments -n shop
    kubectl -n shop logs deploy/shop-gateway-istio --tail=20

When you think you're done: `kdrill verify`

## Read more

- https://istio.io/latest/docs/ops/diagnostic-tools/
- https://istio.io/latest/docs/ops/common-problems/network-issues/
- https://istio.io/latest/docs/ops/common-problems/security-issues/
- https://istio.io/latest/docs/ops/diagnostic-tools/istioctl-analyze/
