# Circuit breaking and outlier detection

## Concept

Two DestinationRule features protect a service from bad backends and from
too much load. Both are enforced by each **caller's** sidecar, per
destination cluster:

    apiVersion: networking.istio.io/v1
    kind: DestinationRule
    spec:
      host: ledger
      trafficPolicy:
        outlierDetection:
          consecutive5xxErrors: 5    # this many 5xx in a row from one Pod...
          interval: 10s              # (how often ejections are re-evaluated)
          baseEjectionTime: 30s      # ...takes it out of rotation this long (x number of ejections)
          maxEjectionPercent: 100    # how much of the pool may be ejected at once
        connectionPool:
          tcp:
            maxConnections: 100      # connections to the whole service
          http:
            http1MaxPendingRequests: 10  # requests waiting for a connection
            http2MaxRequests: 100        # concurrent requests (HTTP/2 or all, depending on version)
            maxRequestsPerConnection: 0  # 0 = unlimited keep-alive

**Outlier detection** is passive health checking. Kubernetes readiness
probes only see what the probe sees; a Pod can pass `/healthz` and still
fail every real request. Envoy watches real responses: after
`consecutive5xxErrors` (or `consecutiveGatewayErrors`) failures in a row
from one endpoint, that endpoint is **ejected** for `baseEjectionTime`,
longer each time it happens again. Ejected endpoints come back
automatically. Connection failures count as errors too.

**Circuit breaking** caps how much a caller sends to a service at once.
When the limits are reached, Envoy does not queue forever: it answers
`503` immediately, with the response header `x-envoy-overloaded: true` and
the access-log flag `UO` (upstream overflow). Failing fast protects the
overloaded service and frees the caller's threads and memory.

Both are per caller sidecar: 10 callers with `maxConnections: 1` can still
open 10 connections in total.

## The situation

Namespace `bank`: the curl client `teller` calls `ledger`. `ledger` has two
Pods: `ledger` (stable) and `ledger-canary`, a bad release whose server
listens on the wrong port, so every request it receives fails with 503,
while its Pod stays Ready. The VirtualService `ledger` disables retries so
that you see every failure. There is no DestinationRule.

Istio trims Envoy's statistics to a small default set to save memory;
`teller`'s Pod template has a `proxy.istio.io/config` annotation
(`proxyStatsMatcher`) that keeps the outlier-detection and overflow
counters, so you can watch them.

## Your task

Write a DestinationRule `ledger` (host `ledger`) so that, without touching
the Pods or the VirtualService:

- a ledger Pod that returns 5xx a few times in a row (at most 3) is
  ejected: at least 27 of 30 sequential requests from `teller` succeed;
- concurrency is capped at 1 connection and 1 pending request: of 10
  concurrent requests that each take 1 s, at least 5 are rejected at once
  with `503` and `x-envoy-overloaded: true`, and at least one succeeds.

## Useful commands

    kubectl -n bank exec deploy/teller -c curl -- sh -c 'for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code} " ledger:8000/get; done; echo'
    kubectl -n bank exec deploy/teller -c curl -- curl -s -Z --parallel-immediate -o /dev/null \
      -w '%{http_code} %header{x-envoy-overloaded}\n' ledger:8000/delay/1 ledger:8000/delay/1 ledger:8000/delay/1 ledger:8000/delay/1
    istioctl proxy-config endpoints deploy/teller -n bank --cluster 'outbound|8000||ledger.bank.svc.cluster.local'   # OUTLIER CHECK column
    istioctl proxy-config clusters deploy/teller -n bank --fqdn ledger.bank.svc.cluster.local -o json | grep -A12 circuitBreakers
    kubectl -n bank exec deploy/teller -c istio-proxy -- pilot-agent request GET stats | grep -E 'ledger.*(outlier_detection|overflow)'

When you think you're done: `kdrill verify`

## On a real cluster

Limits like `maxConnections: 1` only make sense in a demo. Real values come
from load tests: high enough that normal peaks never trip them. Keep
`maxEjectionPercent` below 100 on small pools you can't afford to empty, and
remember the ejection is per caller: each sidecar learns separately.

## Read more

- https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/
- https://istio.io/latest/docs/reference/config/networking/destination-rule/#OutlierDetection
- https://istio.io/latest/docs/reference/config/networking/destination-rule/#ConnectionPoolSettings
- https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking
