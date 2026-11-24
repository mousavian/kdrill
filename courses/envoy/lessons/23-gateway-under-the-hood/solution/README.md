# Solution

From the lesson directory:

    kubectl apply -f solution/shop.yaml
    sh solution/answers.sh

The bug: the `/cart` rule referenced `cart` port 8080, but the Service only
has port 80. Envoy Gateway reported `ResolvedRefs: False` on the route
and, as the Gateway API requires for invalid backends, programmed that rule
to answer **500**.

How the objects map to Envoy (names as Envoy Gateway v1.9 generates them):

| Gateway API | Envoy | Name |
|---|---|---|
| Gateway `edge`, listener `http` (port 80) | listener (LDS) on `0.0.0.0:10080` | `lab/edge/http` |
| (same) | route configuration (RDS) | `lab/edge/http` |
| hostname `shop.lab` of HTTPRoute `shop` | virtual host | `lab/edge/http/shop_lab` |
| rule 0 (`/cart`) | route + cluster (CDS) | `httproute/lab/shop/rule/0` |
| backendRef `cart:80` | endpoints (EDS) | the cart pods' IPs, port 80 |

Things worth noticing:
- **Ports**: Envoy runs as non-root, so a Gateway port below 1024 is bound
  as port + 10000 inside the pod; the Service maps 80 to 10080.
- **Endpoints are pod IPs**, from EndpointSlices, not the ClusterIP:
  everything from lessons 04-10 (balancing, health, outlier detection,
  circuit breakers) works per pod.
- Routes carry metadata naming the Gateway API object they came from
  (`filter_metadata.envoy-gateway.resources`), and each route has a stable
  name, so you can always map back.
- Envoy Gateway also adds its own listeners (`:19001` Prometheus stats,
  `:19003` readiness) and a cluster `xds_cluster` pointing at the
  controller: that gRPC stream is how the config arrives.
- `egctl config envoy-proxy all -n lab` (Envoy Gateway's CLI) and
  `egctl x translate` show the same without port-forwarding, and translate
  manifests offline.

Takeaways: when a Gateway API setup misbehaves, read the statuses first,
then confirm in the Envoy config dump; it's the same Envoy as in Part A.
