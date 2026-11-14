# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    access_log:
    - name: envoy.access_loggers.stdout
      filter:
        status_code_filter:
          comparison:
            op: GE
            value: {default_value: 400, runtime_key: access_log.min_status}
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
        log_format:
          json_format:
            time: "%START_TIME%"
            status: "%RESPONSE_CODE%"
            method: "%REQ(:METHOD)%"
            path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
            upstream: "%UPSTREAM_HOST%"
            flags: "%RESPONSE_FLAGS%"
            duration_ms: "%DURATION%"
            request_id: "%REQ(X-REQUEST-ID)%"

A line now looks like:

    {"status":504,"flags":"UT","path":"/app/slow?wait=3s","upstream":"10.42.0.7:80","duration_ms":1001,...}

Reading **response flags**, the fastest way to know who failed:
- `NR` no route; `UH` no healthy upstream; `UF` upstream connection
  failure; `UT` upstream request timeout; `UO` overflow (circuit breaker);
  `URX` retries exhausted; `UC` upstream connection terminated; `DC`
  downstream (client) closed; `RL` rate limited (local or global); `UAEX`
  denied by ext_authz; `-` nothing special (the status came from the backend).
- `%UPSTREAM_HOST%` tells you which pod; `%DURATION%` vs
  `%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%` separates proxy time from backend time.
- `%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%` logs the path before any rewrite.

Notes:
- In json_format, an operator that makes up a whole value keeps its type
  (`status` is a number).
- Filters: `status_code_filter`, `duration_filter`, `response_flag_filter`,
  `header_filter`, `runtime_filter` (sampling), combined with `and_filter`
  / `or_filter`. Logging only errors and a sample of successes keeps volume sane.
- Other sinks: file, gRPC (`envoy.access_loggers.open_telemetry`) to a
  collector. Envoy Gateway configures these through the EnvoyProxy resource
  (lesson 33), Istio through its Telemetry API.

Takeaways: structured access logs with response flags, upstream host and
request id answer most "what happened to this request?" questions.
