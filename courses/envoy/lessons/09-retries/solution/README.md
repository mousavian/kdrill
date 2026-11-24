# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    routes:
    - match:
        prefix: "/"
        headers:
        - name: ":method"
          string_match: {exact: GET}
      route:
        cluster: echo
        retry_policy:
          retry_on: "5xx,reset,connect-failure"
          num_retries: 2
          per_try_timeout: 1s
          retry_host_predicate:
          - name: envoy.retry_host_predicates.previous_hosts
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.retry.host.previous_hosts.v3.PreviousHostsPredicate
          host_selection_retry_max_attempts: 3
    - match: {prefix: "/"}
      route: {cluster: echo}

How it plays out: a GET lands on the sick pod, gets 503, Envoy retries
(after a short jittered back-off, 25 ms base) on a host it hasn't tried
for this request, which answers 200. The user sees a 200 that took a few
ms longer. `include_request_attempt_count` makes Envoy add
`x-envoy-attempt-count` so the backend can tell (try
`kubectl exec client -- hits -v -n 6 http://envoy:10000/` and curl the
same URL to see the header in the echo output).

Notes:
- `retry_on` conditions: `5xx`, `gateway-error` (502/503/504),
  `reset`, `connect-failure`, `retriable-4xx` (409), `refused-stream`,
  `retriable-status-codes` (with `retriable_status_codes`), and gRPC ones
  (`unavailable`, `resource-exhausted`, ...).
- `per_try_timeout` bounds each attempt; the route `timeout` still bounds
  the whole thing, so `num_retries x per_try_timeout` should fit inside it.
- Envoy doesn't know which requests are idempotent. Retrying a POST that
  timed out after the backend already processed it charges the card twice.
  Restrict retries to safe methods or to idempotent APIs (idempotency keys).
- Retries multiply load exactly when a backend is struggling. The cluster's
  circuit breaker `max_retries` (default 3 concurrent retries, next lesson)
  and `retry_budget` cap that. In a call chain, retry at one layer only.
- The sick pod is still getting a third of first attempts. Combine retries
  with outlier detection (lesson 07) to take it out.

Takeaways: retries turn transient and single-host failures into latency,
not errors, but only for idempotent requests and within a budget.
