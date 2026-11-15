# Resilience: timeouts and retries

## Concept

Every network call needs two decisions: how long to wait, and whether to
try again. In a mesh the client sidecar can make both, consistently, for
every caller, configured on the route in a VirtualService:

    http:
    - route:
      - destination: {host: inventory}
      timeout: 2s                       # whole request, retries included
      retries:
        attempts: 3                     # retries after the first try
        perTryTimeout: 500ms            # optional, per attempt
        retryOn: 5xx,connect-failure,reset

- **timeout**: when it expires, Envoy gives up, resets the upstream request
  and answers `504` (`upstream request timeout`). By default Istio sets no
  route timeout for HTTP.
- **retries.attempts**: the number of *re*tries. Each retry goes to another
  endpoint when possible. Envoy adds `x-envoy-attempt-count` to the upstream
  request so the server can see which attempt it is.
- **retryOn**: which failures to retry. Useful values: `5xx` (any 5xx or
  no response), `gateway-error` (502/503/504), `connect-failure`, `reset`,
  `retriable-status-codes`. Without a `retries` block, Istio retries twice
  on `connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes`,
  which in practice means connection problems and 503, not 500.

Things to keep in mind:

- The overall `timeout` caps everything; with `perTryTimeout` set, each
  attempt also gets its own deadline.
- Retries multiply load. If every layer of a call chain retries 3 times, a
  failing backend at the bottom sees 4 x 4 x 4 = 64 requests per user
  request (a "retry storm"). Retry at one layer, with a budget.
- Only retry what is safe to repeat: GETs and idempotent writes.

## The situation

Namespace `shop` has a curl client `web` and an HTTP server `inventory`
(go-httpbin: `/delay/N` answers after N seconds, `/unstable?failure_rate=F`
fails with 500 at rate F, `/status/C` answers with status C). The
VirtualService `inventory` has a single route `main` with no timeout and no
retry policy. `web`'s Pod template keeps Envoy's retry and timeout counters
(annotation `proxy.istio.io/config` with `proxyStatsMatcher`; Istio trims
most per-cluster statistics by default).

## Your task

Change route `main` of VirtualService `inventory` so that:

- a request never takes more than 2 seconds: `/delay/5` gets a `504` after
  about 2 s, while `/delay/1` still succeeds;
- failed requests are retried up to 3 times on 5xx: at least 45 of 50 calls to
  `/unstable?failure_rate=0.4` succeed, and a request to `/status/500`
  reaches inventory exactly 4 times.

## Useful commands

    kubectl -n shop exec deploy/web -c curl -- curl -s -w '\n%{http_code} %{time_total}s\n' inventory:8000/delay/5
    kubectl -n shop exec deploy/web -c curl -- curl -s inventory:8000/headers   # see X-Envoy-Attempt-Count
    kubectl -n shop logs deploy/inventory -c inventory --tail=10                # one line per attempt
    istioctl proxy-config routes deploy/web -n shop --name 8000 -o json | grep -A12 retryPolicy
    kubectl -n shop exec deploy/web -c istio-proxy -- pilot-agent request GET stats | grep -E 'inventory.*upstream_rq_(retry|timeout)'

When you think you're done: `kdrill verify`

## Read more

- https://istio.io/latest/docs/tasks/traffic-management/request-timeouts/
- https://istio.io/latest/docs/concepts/traffic-management/#retries
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry
- https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on
