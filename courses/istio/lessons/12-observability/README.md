# Observability: access logs and metrics with the Telemetry API

## Concept

Every sidecar sees every request, so the mesh gives you uniform telemetry
for all services without touching their code:

- **Metrics**: each proxy keeps Prometheus counters and histograms, the
  most important being `istio_requests_total` (labels: source and
  destination workload, namespace, principal, response code, response
  flags, mTLS or not, ...) and `istio_request_duration_milliseconds`. A
  request is counted twice: by the client proxy (`reporter="source"`) and
  the server proxy (`reporter="destination"`). Prometheus scrapes them at
  `:15020/stats/prometheus` on each Pod. This lab runs no Prometheus; you
  read the same endpoint directly.
- **Access logs**: one line per request from Envoy, off by default in this
  install. The default format shows method, path, status, **response
  flags** (`UF` upstream connection failure, `UO` overflow, `NR` no route,
  `UH` no healthy upstream, `URX` retries exhausted, `DI`/`FI` injected
  delay/abort, `UT` timeout), timings, upstream host and cluster.
- **Traces**: proxies can emit spans (to Zipkin/OpenTelemetry); the
  application must forward trace headers. Not used in this lab.

The **Telemetry API** configures all of this, with the usual scopes: in
`istio-system` for the mesh, in a namespace for that namespace, with a
`selector` (or `targetRefs`) for workloads. The narrowest wins.

    apiVersion: telemetry.istio.io/v1
    kind: Telemetry
    metadata: {name: logs, namespace: shop}
    spec:
      accessLogging:
      - providers: [{name: envoy}]           # built-in: Envoy's stdout
        filter:
          expression: response.code >= 500   # CEL over request/response attributes
      metrics:
      - providers: [{name: prometheus}]
        overrides:
        - match: {metric: REQUEST_COUNT, mode: CLIENT_AND_SERVER}   # or CLIENT / SERVER
          tagOverrides:
            team: {value: "request.headers['x-team']"}  # add a label (operation: UPSERT)
            request_protocol: {operation: REMOVE}     # drop a label

Filters keep logs useful and cheap: logging only errors, or only one
workload, instead of every health check. Extra metric labels are powerful
but each distinct value is a new time series; never use unbounded values
(user IDs, raw paths) as labels.

## The situation

Namespace `shop`: the curl client `web` and the service `catalog`. No
access logs, standard metrics only.

## Your task

- Access logs for **every sidecar in `shop`**, but only for requests with a
  response code of 400 or more.
- `catalog`'s server-side request counter (`istio_requests_total`,
  `reporter="destination"`) gets an extra label `tenant` with the value of
  the request header `x-tenant`.

`kdrill verify` sends successful, failing and not-found requests from
`web` with `x-tenant: acme` / `globex`, then reads the sidecar logs of
`catalog` and `web` and catalog's Prometheus endpoint.

## Useful commands

    kubectl -n shop exec deploy/web -c curl -- curl -s -o /dev/null -w '%{http_code}\n' -H 'x-tenant: acme' catalog:8000/status/503
    kubectl -n shop logs deploy/catalog -c istio-proxy --tail=5
    kubectl -n shop exec deploy/catalog -c istio-proxy -- pilot-agent request GET stats/prometheus | grep '^istio_requests_total'
    kubectl -n shop get telemetry
    istioctl x describe pod -n shop <catalog-pod>

When you think you're done: `kdrill verify`

## On a real cluster

Prometheus (with the Istio scrape config) plus Grafana's Istio dashboards
and Kiali give the service graph and golden signals per workload, and an
OpenTelemetry collector receives traces and access logs. On a laptop they
cost more memory than the whole mesh, which is why this course reads the
raw endpoints instead.

## Read more

- https://istio.io/latest/docs/tasks/observability/telemetry/
- https://istio.io/latest/docs/tasks/observability/logs/access-log/
- https://istio.io/latest/docs/reference/config/metrics/
- https://istio.io/latest/docs/tasks/observability/metrics/customize-metrics/
- https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage#config-access-log-format-response-flags
