# Access logs: structured, filtered, with response flags

## Concept

Stats tell you *that* something fails; the access log tells you *which*
request, where it went and why. Access logs are configured on the HCM
(`access_log:`, a list of loggers) and written when a request finishes.

A logger has a sink, a format and an optional filter:

- **Sink**: `envoy.access_loggers.stdout` (the container's log in
  Kubernetes), `file`, or gRPC/OpenTelemetry to a collector.
- **Format**: text with **command operators** (`%RESPONSE_CODE%`,
  `%REQ(header)%`, `%RESP(header)%`, `%UPSTREAM_HOST%`, `%DURATION%`,
  `%START_TIME%`, `%DOWNSTREAM_REMOTE_ADDRESS%`, ...) or `json_format` /
  `typed_json_format`, a map of keys to operators: one JSON object per line,
  ready for Loki, Elasticsearch or CloudWatch.
- **Filter**: `status_code_filter`, `duration_filter`,
  `response_flag_filter`, `header_filter`, `runtime_filter` (sampling),
  combined with `and_filter` / `or_filter`.

The most valuable field is `%RESPONSE_FLAGS%`. It says why Envoy did what
it did: `NR` (no route), `UH` (no healthy upstream), `UF` (connection
failure), `UT` (upstream timeout), `UO` (circuit breaker overflow), `URX`
(retries exhausted), `DC` (client went away), `RL` (rate limited), and `-`
when the response came from the backend normally. Together with
`%UPSTREAM_HOST%` (which pod) and `%REQ(X-REQUEST-ID)%` (correlate with app
logs and traces) you can explain almost any failed request.

## The situation

Envoy routes `/app...` to `web` with a 1 s timeout and `/down...` to a cluster
whose headless Service currently has no pods. It has no access log.

## Your task

Add an access log to the HCM so that:

- it writes one JSON object per line to stdout (`kubectl logs deploy/envoy`);
- each line has the keys `status`, `method`, `path`, `upstream`, `flags`,
  `duration_ms` and `request_id` (the client's `x-request-id`); `path` is
  the path with query as the client sent it, `duration_ms` a number;
- only requests with status 400 or higher are logged.

verify sends four requests with unique request ids: a 200, a 404 with no
route (`NR`), a 503 with no healthy upstream (`UH`) and a 504 timeout (`UT`),
then reads the log.

## Useful commands

    kubectl exec client -- curl -s http://envoy:10000/down/x
    kubectl exec client -- curl -s 'http://envoy:10000/app/slow?wait=3s'
    kubectl logs deploy/envoy --tail=5
    kubectl logs deploy/envoy -f        # follow while you send requests

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/observability/access_log/usage
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/accesslog/v3/accesslog.proto
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/extensions/access_loggers/stream/v3/stream.proto
