# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    - match: {prefix: "/api/"}
      route: {cluster: api, timeout: 1s}
    - match: {prefix: "/reports/"}
      route: {cluster: reports, timeout: 10s}

The route timeout covers the whole upstream exchange: from when Envoy has
the complete request until the complete response has arrived (including
all retries). When it fires, Envoy resets the upstream request and answers
`504 upstream request timeout`; the access log shows the flag `UT`.

The timeout family, from outside in:
- HCM `request_timeout`: the whole downstream request (off by default),
  `request_headers_timeout`: time to receive the headers.
- HCM `stream_idle_timeout` (5 min default): no bytes in either direction on a
  stream, important for streaming and long polls. `idle_timeout` in
  `common_http_protocol_options`: idle downstream connections.
- Route `timeout` (15 s default, `0s` disables it, needed for streaming
  responses such as server-sent events or LLM token streams) and `idle_timeout`
  (per-route stream idle).
- Retry `per_try_timeout` (next lesson).
- Cluster `connect_timeout` (5 s default): TCP (and TLS) connection setup.

Envoy forwards the remaining budget as `x-envoy-expected-rq-timeout-ms` so
the next hop can give up in time. A caller can also *ask* for a timeout with
`x-envoy-upstream-rq-timeout-ms`; Envoy honours that from internal callers,
so on an edge proxy make sure untrusted clients can't set x-envoy-* headers
(`use_remote_address`, `internal_address_config`).

Takeaways: set explicit timeouts per route; short for interactive calls,
long or disabled for streaming; and make them shrink along the call chain.
