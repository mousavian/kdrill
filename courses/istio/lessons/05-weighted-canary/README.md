# Canary releases: weighted routing and traffic mirroring

## Concept

A **canary release** sends a small share of real traffic to a new version,
watches its error rate and latency, and then shifts more traffic (or rolls
back) without touching Deployments. With replicas alone you can only split
by Pod count (1 of 5 Pods = 20%); with the mesh the split is per request and
independent of replica counts:

    http:
    - route:
      - destination: {host: catalog, subset: v1}
        weight: 90
      - destination: {host: catalog, subset: v2}
        weight: 10

Weights within a route add up to 100. Tools like Argo Rollouts and Flagger
automate exactly this: they edit these weights step by step while checking
metrics.

**Traffic mirroring** (shadowing) goes one step earlier: the sidecar sends a
*copy* of each request to another destination, fire-and-forget, and drops
the copy's response. The new version sees production traffic patterns
without any user ever getting its answer. Mirrored requests carry the
`Host`/`:authority` with a `-shadow` suffix, so the receiver can tell.

    http:
    - route: [...]
      mirror: {host: catalog, subset: v3}
      mirrorPercentage: {value: 100.0}

Mirrors are only safe for idempotent or side-effect-free requests: a
mirrored `POST /orders` really creates a second order.

## The situation

Namespace `shop` runs `catalog-v1`, `catalog-v2` and `catalog-v3` behind the
Service `catalog`, with a DestinationRule defining subsets `v1`, `v2`, `v3`
and a VirtualService `catalog` sending 100% to v1. A curl client `web`
calls catalog.

## Your task

Change the VirtualService `catalog` so that:

- about 80% of requests are answered by v1 and 20% by v2;
- v3 receives a mirrored copy of every request, and never answers a client.

`kdrill verify` sends 200 requests and accepts v1 between 140 and 180 and
v2 between 20 and 60, then counts the copies in v3's request log.

## Useful commands

    kubectl -n shop exec deploy/web -c curl -- sh -c 'for i in $(seq 50); do curl -s catalog:8000/hostname; done' | sort | uniq -c
    kubectl -n shop logs deploy/catalog-v3 -c catalog --tail=5
    istioctl proxy-config routes deploy/web -n shop --name 8000 -o json | grep -B2 -A12 weightedClusters

When you think you're done: `kdrill verify`

## On a real cluster

A canary is only as good as what you watch while it runs: per-version
error rate and latency, from Istio's metrics (`istio_requests_total` with
`destination_version`, lesson 12) in Prometheus/Grafana or Kiali. Rollout
controllers (Argo Rollouts, Flagger) drive the weights from those metrics.

## Read more

- https://istio.io/latest/docs/tasks/traffic-management/traffic-shifting/
- https://istio.io/latest/docs/tasks/traffic-management/mirroring/
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRoute
- https://istio.io/latest/blog/2017/0.1-canary/
