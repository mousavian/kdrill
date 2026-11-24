# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    circuit_breakers:
      thresholds:
      - priority: DEFAULT
        max_connections: 4
        max_pending_requests: 2
        max_requests: 4
        max_retries: 1

What happens in the burst: Envoy opens 4 connections to reports and sends
4 requests. Two more wait in the pending queue for a connection. Request
number 7 and later overflow the queue: Envoy answers right away with `503`
and `x-envoy-overloaded: true` (access log flag `UO`), and counts
`upstream_rq_pending_overflow`. After 2 s the first four finish, the two
waiting requests run, and the backend never sees more than 4 at once.

Notes:
- The limits are per cluster per Envoy, shared across worker threads (they
  can be exceeded slightly, by the number of workers, because the check
  isn't atomic). With 10 Envoy replicas, the backend can see 10x the limit.
- `max_connections` and `max_pending_requests` matter for HTTP/1.1,
  `max_requests` for HTTP/2 (many requests per connection), `max_retries`
  for concurrent retries.
- Gauges `circuit_breakers.default.cx_open`, `rq_pending_open`, ... show when
  a breaker is tripped, and `remaining_*` show headroom (with
  `track_remaining: true`).
- This is load shedding at the client side. The "circuit breaker" name is
  historical: Envoy doesn't open a circuit after failures (that's outlier
  detection); it caps concurrency. Admission control and adaptive
  concurrency filters adapt the limit automatically.

Takeaways: give each upstream a concurrency budget it can actually serve;
failing fast with 503 beats a growing queue that times out for everyone.
