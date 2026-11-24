# Circuit breaking: protect a fragile backend from bursts

## Concept

Envoy's **circuit breakers** are concurrency limits per cluster. When one is
reached, new requests are not queued indefinitely but rejected
immediately with `503` and the header `x-envoy-overloaded: true`. The
caller gets a fast, clear failure, and the backend gets a load it can
handle instead of a queue that makes every request slow.

`circuit_breakers.thresholds` (per routing priority, usually `DEFAULT`):

- `max_connections` (default 1024): open connections to all hosts of the
  cluster. With HTTP/1.1 each in-flight request needs its own
  connection, so this is the concurrency limit.
- `max_pending_requests` (default 1024): requests waiting for a connection
  to become available. Beyond it, overflow.
- `max_requests` (default 1024): concurrent requests, the limit that
  matters for HTTP/2 and gRPC (many requests per connection).
- `max_retries` (default 3): concurrent retries, the guard against retry
  storms from the previous lesson.

The limits are enforced by each Envoy on its own; a fleet of N Envoys lets
N times the limit through. `/clusters` shows the configured values
(`reports::default_priority::max_connections::...`), and the counters
`upstream_rq_pending_overflow`, `upstream_cx_overflow`,
`upstream_rq_retry_overflow` count rejections; the access log flag is `UO`.

Despite the name, nothing "opens" after failures here; that's outlier
detection (lesson 07). Circuit breakers are about concurrency.

## The situation

`reports` is a single, fragile pod: more than 4 concurrent requests and it
gets into trouble. Its requests are slow (verify asks for `?wait=2s`).
Envoy's cluster `reports` has default limits.

## Your task

Configure circuit breakers on the cluster `reports` in the ConfigMap
`envoy` so that, when 20 two-second requests arrive at once:

- at most 4 run concurrently and at most 2 more may wait (verify accepts 4
  to 8 successful requests, since Envoy's limit can be exceeded by one
  per worker);
- at least 12 are rejected immediately with `503` and
  `x-envoy-overloaded: true`, and Envoy counts them as pending overflow;
- normal sequential traffic is unaffected;
- `/clusters` shows `max_connections` 4 for `reports`.

## Useful commands

    kubectl exec client -- hits -n 20 -c 20 -r x-envoy-overloaded 'http://envoy:10000/reports/q?wait=2s'
    kubectl exec client -- curl -s envoy:9901/clusters | grep default_priority
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=reports.(upstream_rq_pending_overflow|circuit_breakers)'

`hits -c 20` runs 20 requests in parallel; `-r x-envoy-overloaded` reports
that response header instead of the backend name.

When you think you're done: `kdrill verify` (about 6 s).

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/circuit_breaking
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/cluster/v3/circuit_breaker.proto
- https://www.envoyproxy.io/docs/envoy/v1.39.5/faq/load_balancing/transient_failures
