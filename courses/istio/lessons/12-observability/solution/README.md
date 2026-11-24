# Solution

    kubectl apply -f solution/telemetry.yaml

- `Telemetry shop-logs` (namespace `shop`, no selector): provider `envoy`
  with the CEL filter `response.code >= 400`. Every sidecar in `shop` now
  writes a line to its `istio-proxy` stdout for each failed request, both
  on the client side (`web`, outbound) and the server side (`catalog`,
  inbound). Successful requests are not logged.
- `Telemetry catalog-metrics` (selector `app: catalog`): for
  `REQUEST_COUNT` in `SERVER` mode, add the label `tenant` from
  `request.headers['x-tenant']`. catalog's `istio_requests_total{reporter="destination",...}`
  now carries `tenant="acme"` / `tenant="globex"`.

A log line, for reference:

    [2026-...] "GET /status/503?... HTTP/1.1" 503 - via_upstream - "-" 0 0 0 0 "-" "curl/8.23.0" "<request id>" "catalog:8000" "10.42.0.7:8080" inbound|8080|| ...

`503 -`: status and response flags (`-` = none; the 503 came from the
application, `via_upstream`). Compare with an injected fault (lesson 07,
flag `FI`) or a circuit-breaker overflow (lesson 08, flag `UO`).

Takeaways:
- Telemetry resources scope like other Istio policies: mesh, namespace,
  workload.
- Filter access logs; add metric labels only with bounded values.
- `/stats/prometheus` on any sidecar shows what Prometheus would scrape.
