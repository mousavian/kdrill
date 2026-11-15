# Inside the sidecar: listeners, routes, clusters and protocol selection

## Concept

Everything Istio does ends up as **Envoy configuration**. Knowing its four
building blocks lets you debug almost any mesh problem:

| Envoy object | What it is | In a sidecar |
|---|---|---|
| **listener** | an IP:port Envoy accepts connections on, plus a filter chain | `virtualOutbound` (15001) catches all outgoing traffic, `virtualInbound` (15006) all incoming; per-port listeners such as `0.0.0.0_8000` hold the real logic |
| **route** | for HTTP: which virtual host / path goes to which cluster | one route table per port, e.g. `8000`, built from Services and VirtualServices |
| **cluster** | a named group of upstream endpoints plus policy (load balancing, TLS, circuit breakers) | `outbound|8000||catalog.store.svc.cluster.local`, built from Services and DestinationRules |
| **endpoint** | an actual Pod IP:port in a cluster | from the Service's EndpointSlices |

A request from `frontend` to `catalog:8000` is redirected by iptables to
the sidecar's outbound listener, matched to the `8000` listener, looked up
in route table `8000` (virtual host `catalog.store.svc.cluster.local:8000`),
sent to cluster `outbound|8000||catalog...`, and load-balanced to one
endpoint. istiod generates all of it and pushes it over xDS (LDS for
listeners, RDS routes, CDS clusters, EDS endpoints). You can read it with:

    istioctl proxy-config listeners|routes|clusters|endpoints deploy/frontend -n store
    istioctl proxy-config all deploy/frontend -n store -o json   # the full config_dump

**Protocol selection.** HTTP features (VirtualService http routes, retries,
header manipulation, HTTP metrics, L7 authorization) only work if Istio
knows a port carries HTTP. For each Service port it uses, in order:

1. `appProtocol` on the port (`http`, `http2`, `grpc`, `tcp`, `tls`, ...);
2. the port **name** prefix: `http`, `http-anything`, `grpc-...`, `tcp-...`;
3. otherwise, outbound protocol sniffing (works for HTTP/1.1, costs a little
   latency, and does not help server-first protocols).

If a port is declared TCP, Envoy only proxies bytes: no HTTP route exists,
and a VirtualService `http:` section for that host is silently ignored.
Nothing warns you (not even `istioctl analyze`); the proxy config shows it.

## The situation

Namespace `store` is in the mesh: `frontend` (a curl client), `catalog` and
`reviews` (HTTP servers). The platform team's VirtualService `catalog` sets
the response header `x-route: catalog-mesh`, but nobody has ever seen that
header, and `reviews` responses show no sign of Envoy's HTTP handling.

## Your task

Fix the two **Services** (not the VirtualService, not the workloads) so
that Istio handles their port 8000 as HTTP:

- `frontend`'s sidecar has HTTP routes for `catalog.store.svc.cluster.local:8000`
  and `reviews.store.svc.cluster.local:8000`;
- responses from `catalog` carry `x-route: catalog-mesh`;
- responses from `reviews` carry `x-envoy-upstream-service-time` (the header
  Envoy's HTTP router adds);
- both Services keep port 8000 -> targetPort 8080.

Before fixing, look around with `istioctl proxy-config`: it is the tool for
every later lesson.

## Useful commands

    kubectl -n store get svc catalog reviews -o yaml
    istioctl proxy-config listeners deploy/frontend -n store --port 8000
    istioctl proxy-config routes deploy/frontend -n store --name 8000 -o json
    istioctl proxy-config clusters deploy/frontend -n store --fqdn catalog.store.svc.cluster.local
    istioctl proxy-config endpoints deploy/frontend -n store --cluster 'outbound|8000||catalog.store.svc.cluster.local'
    kubectl -n store exec deploy/frontend -c curl -- curl -sI catalog:8000/get

When you think you're done: `kdrill verify`

## Read more

- https://istio.io/latest/docs/ops/configuration/traffic-management/protocol-selection/
- https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/
- https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request
- https://istio.io/latest/docs/ops/deployment/application-requirements/
