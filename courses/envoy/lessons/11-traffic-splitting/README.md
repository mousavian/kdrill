# Traffic splitting: a 90/10 canary with an opt-in header

## Concept

Because Envoy decides per request where to send it, rolling out a new
version doesn't have to be all or nothing. A route action can use
**weighted clusters** instead of a single cluster:

    route:
      weighted_clusters:
        clusters:
        - {name: web-v1, weight: 90}
        - {name: web-v2, weight: 10}

Each request picks a cluster at random in proportion to the weights. Raise
v2's weight step by step while watching its error rate and latency
(`cluster.web-v2.upstream_rq_5xx`, `upstream_rq_time`), and roll back by
setting it to 0. Per-cluster stats are what make this safe: you can compare
v1 and v2 directly.

Combine it with **header-based routing** for testers and automated checks:
a route that matches `x-canary: always` and goes straight to v2, placed
before the weighted route (first match wins).

Related tools: `runtime_fraction` on a route match (a percentage you can
change at runtime without a config push), and `request_mirror_policies`
(shadow a copy of the traffic to v2 and discard the answers).

Kubernetes alone can only approximate a canary by replica counts behind
one Service; with Envoy the split is exact and independent of how many
pods each version runs. Envoy Gateway exposes the same feature as
`backendRefs[].weight` in an HTTPRoute (lesson 25).

## The situation

`web-v1` (answers `Name: v1`) gets all traffic. `web-v2` (`Name: v2`) is
deployed, has its Service and an Envoy cluster, and gets nothing.

## Your task

- requests without special headers: about 90% v1, 10% v2 (verify sends 200
  and accepts 6 to 36 for v2), done with `weighted_clusters`;
- requests with `x-canary: always`: all v2;
- any other value of `x-canary` is treated like no header.

## Useful commands

    kubectl exec client -- hits -n 200 http://envoy:10000/
    kubectl exec client -- hits -n 20 http://envoy:10000/ -H 'x-canary: always'
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=cluster.web-v.\.upstream_rq_2xx'

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/traffic_splitting
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#config-route-v3-weightedcluster
