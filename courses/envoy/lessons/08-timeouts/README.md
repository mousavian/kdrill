# Timeouts: fail fast where it matters

## Concept

Without timeouts, a slow upstream holds connections, threads and users
hostage. Envoy has timeouts at several layers:

- **Route `timeout`** (default **15 s**): from the moment Envoy has the whole
  request until the whole response has arrived, retries included. When it
  fires Envoy answers `504` with the body `upstream request timeout`.
  `0s` disables it, required for long streams (server-sent events, LLM
  token streaming, downloads).
- Route `idle_timeout` and HCM `stream_idle_timeout` (default 5 min): no
  activity on a stream.
- HCM `request_timeout` / `request_headers_timeout`: limits on how long the
  *client* may take to send its request (slowloris protection).
- Cluster `connect_timeout` (default 5 s): TCP/TLS connection setup to a host.
- Retry `per_try_timeout`: each attempt (next lesson).

A timeout is part of the API contract: an interactive endpoint should fail
in a second or two, so the caller can retry or degrade, while a report
may legitimately take a while. Set timeouts per route, not one global value.

Envoy tells the upstream how much time is left with the request header
`x-envoy-expected-rq-timeout-ms` (you've seen it in the echo output), so a
service can stop work that nobody waits for anymore.

When a timeout fires, look at Envoy's access log (lesson 14) for the
response flag `UT` (upstream request timeout) and at the counter
`cluster.<name>.upstream_rq_timeout`.

## The situation

Envoy routes `/api/` to `api` and `/reports/` to `reports`. Both backends
answer immediately, unless called with `?wait=<duration>` (e.g.
`?wait=3s`), then they wait that long. Neither route sets a timeout.

## Your task

- `/api/...` requests that take longer than 1 s are cut off with Envoy's 504
  after about 1 s; fast ones (200 ms) still answer 200;
- the `/reports/` route has a 10 s timeout, so a 3 s report answers 200.

## Useful commands

    kubectl exec client -- curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' 'http://envoy:10000/api/items?wait=3s'
    kubectl exec client -- curl -si 'http://envoy:10000/reports/daily?wait=3s'
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=upstream_rq_timeout'
    kubectl edit configmap envoy
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

When you think you're done: `kdrill verify` (it waits for a 3 s report, so
it takes about 6 s).

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/faq/configuration/timeouts
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/router_filter#x-envoy-upstream-rq-timeout-ms
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#envoy-v3-api-field-config-route-v3-routeaction-timeout
