# Retries: hide a bad host from users, safely

## Concept

A **retry policy** on a route makes the router try again when an attempt
fails in a way you list in `retry_on`:

- `5xx`: any 5xx response, plus resets and connect failures;
  `gateway-error`: only 502/503/504; `reset`, `connect-failure`,
  `refused-stream`; `retriable-status-codes` with a list of codes;
  gRPC conditions (`unavailable`, `cancelled`, ...).
- `num_retries` (default 1 when a policy exists), `per_try_timeout`
  (each attempt; the route `timeout` still bounds the total), and a
  jittered exponential back-off (25 ms base by default).
- `retry_host_predicate`: which hosts a retry may use. The
  `previous_hosts` predicate excludes hosts already tried for this request,
  so a retry doesn't go back to the host that just failed.
- `retry_priority`, `retriable_headers`, rate-limited back-off and more for
  special cases.

Retries are powerful and dangerous:

- **Idempotency.** Envoy retries any method. A POST that failed with a
  reset may have been processed. Retry only requests that are safe to repeat
  (GET, PUT with full replacement, idempotency keys).
- **Amplification.** Under overload, retries add load exactly when it
  hurts. Cap them: the cluster circuit breaker `max_retries` (default 3
  concurrent retries per cluster) or a `retry_budget`, and retry at one
  layer of a call chain only.

The counters `cluster.<name>.upstream_rq_retry`, `upstream_rq_retry_success`
and `upstream_rq_retry_overflow` show what happened; the access log flag
`URX` means retries were exhausted.

## The situation

Same pods as in lesson 07: the headless Service `echo` selects two echo pods
and the pod `sick`, which answers everything with 503. This time you'll
handle it with retries, not ejection.

## Your task

Change the routes in the ConfigMap `envoy` so that:

- GET requests that fail are retried, at most 2 times, never on a host
  that already failed them (`previous_hosts`); 60 GETs all answer 200, and
  Envoy's retry counter shows it happened;
- POST requests are never retried (a third of them keep failing; that's
  expected and correct);

Rules: keep the sick pod in the Service and the cluster (3 hosts), and no
outlier detection or health checks on the cluster.

## Useful commands

    kubectl exec client -- hits -n 30 http://envoy:10000/items
    kubectl exec client -- hits -n 30 http://envoy:10000/orders -X POST -d '{}'
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=echo.upstream_rq_retry'
    kubectl exec client -- curl -s envoy:9901/clusters | grep -E 'rq_total|rq_error'

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/http/http_routing#retry-semantics
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/router_filter#x-envoy-retry-on
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#config-route-v3-retrypolicy
