Both features live in the `Telemetry` resource (telemetry.istio.io/v1):

    kubectl explain telemetry.spec.accessLogging
    kubectl explain telemetry.spec.metrics.overrides

The built-in access log provider is called `envoy` (it logs to the
sidecar's stdout); the metrics provider is called `prometheus`.
---
Access logs, namespace-wide (no selector):

    accessLogging:
    - providers: [{name: envoy}]
      filter:
        expression: response.code >= 400

Metrics, with `selector: {matchLabels: {app: catalog}}`:

    metrics:
    - providers: [{name: prometheus}]
      overrides:
      - match: {metric: REQUEST_COUNT, mode: SERVER}
        tagOverrides:
          tenant: {value: "request.headers['x-tenant']"}
---
    kubectl apply -f solution/telemetry.yaml
    kubectl -n shop exec deploy/web -c curl -- curl -s -H 'x-tenant: acme' catalog:8000/status/503
    kubectl -n shop logs deploy/catalog -c istio-proxy --tail=3
