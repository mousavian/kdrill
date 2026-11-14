# The admin interface: what is Envoy actually doing?

## Concept

When traffic through Envoy fails, the first question is whether the error
came from the backend or from Envoy itself. Envoy-generated errors have
`server: envoy`, a short plain-text body, and fall into a few families:

- **404, empty body**: no route matched (no virtual host for the Host
  header, or no route in it for the path).
- **503 "no healthy upstream"**: the cluster has no usable host (none
  discovered, or all ejected/unhealthy).
- **503 "upstream connect error or disconnect/reset before headers"**: Envoy
  picked a host but couldn't connect, or the connection was reset before a
  response arrived.
- **504 "upstream request timeout"**: the route timeout fired (lesson 08).

The **admin interface** tells you why. Most useful endpoints:

- `/clusters`: every cluster, every host Envoy currently has in it (after
  DNS or EDS), per-host counters (`cx_active`, `rq_total`, `rq_error`) and
  `health_flags` (`healthy`, `/failed_active_hc`, `/failed_outlier_check`).
- `/config_dump`: the full running config, by section, e.g.
  `?resource=static_clusters`, `?resource=static_route_configs`,
  `?resource=dynamic_active_clusters`. Add `&include_eds` to see endpoints.
- `/stats`: counters and gauges, filterable with a regex:
  `/stats?filter=cluster.shop.` or `/stats?filter=no_route`. Names follow
  the config: `listener.<address>.*`, `http.<stat_prefix>.*` for an HCM,
  `cluster.<name>.*` for a cluster (e.g. `upstream_rq_503`,
  `upstream_cx_connect_fail`, `membership_healthy`).
- `/ready`, `/server_info`, `/listeners`, `/logging` (change log levels at
  runtime: `POST /logging?level=debug`).

Envoy Gateway and Istio sidecars expose the same interface (on
127.0.0.1:19000 and :15000), so this is the debugging skill you'll use in
every later lesson.

## The situation

Envoy in `lab` serves three sites on port 10000, chosen by the Host header:
`shop.lab`, `catalog.lab` and `api.lab`, each with its own backend
Deployment and Service (all listening on port 80). None of the three works,
each for a different reason.

## Your task

Fix the ConfigMap `envoy` (not the Services or Deployments) so that:

- `Host: shop.lab`, `catalog.lab` and `api.lab` each answer 200 from their
  own backend, for any path (verify uses `/products/42` and `/`);
- an unknown host still gets Envoy's 404 (keep the three virtual hosts; no
  catch-all).

## Useful commands

    kubectl exec client -- curl -si http://envoy:10000/products/42 -H 'Host: shop.lab'
    kubectl exec client -- hits http://envoy:10000/ -H 'Host: catalog.lab'
    kubectl exec client -- curl -s envoy:9901/clusters
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=cluster.shop.'
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=static_route_configs'
    kubectl port-forward svc/envoy 9901    # browse http://localhost:9901
    kubectl get svc

When you think you're done: `kdrill verify`

## On a real cluster

Never expose the admin interface like the lab does (0.0.0.0, through a
Service): it has no authentication and can change log levels, drain
listeners or shut Envoy down. Bind it to 127.0.0.1 and use `kubectl
port-forward` to the pod, which is exactly what you'll do with Envoy
Gateway in Part B.

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/operations/admin
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/upstream/cluster_manager/cluster_stats
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/stats
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/observability/access_log/usage
