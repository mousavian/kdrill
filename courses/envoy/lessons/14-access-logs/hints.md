An access log belongs to the HCM (`access_log:` next to `stat_prefix`), and
is a list of loggers. The one that writes to the container's stdout:

    access_log:
    - name: envoy.access_loggers.stdout
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog

Without a `log_format` it uses the default text format. Look at it with
`kubectl logs deploy/envoy`.
---
- `log_format: {json_format: {status: "%RESPONSE_CODE%", method: "%REQ(:METHOD)%", path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%", upstream: "%UPSTREAM_HOST%", flags: "%RESPONSE_FLAGS%", duration_ms: "%DURATION%", request_id: "%REQ(X-REQUEST-ID)%"}}`
- A filter on the logger:
  `filter: {status_code_filter: {comparison: {op: GE, value: {default_value: 400, runtime_key: access_log.min_status}}}}`
  (`runtime_key` is required; any name works).
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
    kubectl exec client -- curl -s http://envoy:10000/down
    kubectl logs deploy/envoy | tail -n 3
