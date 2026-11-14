# Local rate limiting: a token bucket per route

## Concept

Rate limiting protects a backend (and your bill) from clients that send
too much. Envoy has two kinds:

- **Local**: the `envoy.filters.http.local_ratelimit` HTTP filter keeps a
  **token bucket** in each Envoy process. No external dependency, no added
  latency, but the limit is per Envoy instance.
- **Global**: the `envoy.filters.http.ratelimit` filter asks a rate limit
  service (gRPC, usually envoyproxy/ratelimit + Redis) for every request,
  so limits hold across the fleet and per client key.

A token bucket has `max_tokens` (the burst size), `tokens_per_fill` and
`fill_interval` (the sustained rate). Each request takes a token; an empty
bucket means the request is answered by Envoy itself with **429** (access
log flag `RL`) and never reaches the backend.

HTTP filters run in the order of `http_filters`, and the router must be
last. Many filters, including this one, can be configured globally in the
chain and **per route** with `typed_per_filter_config` (keyed by the filter
name). A common pattern: put the filter in the chain without a bucket, and
give buckets only to the routes that need them.

Two fractions control it: `filter_enabled` (evaluate the limit) and
`filter_enforced` (actually reject). Both default to 0%, so a bucket alone
does nothing. Enabled without enforced is a dry run: the
`http_local_rate_limit.rate_limited` stat counts what would have been
limited.

## The situation

Envoy routes `/health` and `/api/...` to the `api` backend, with no limits.

## Your task

- `/api/...`: at most 5 requests per 10 seconds through this Envoy. A burst
  of 12 gets at most 5 through; the rest are answered with 429 and the
  response header `x-local-rate-limit: true`; after 10 s, 5 more succeed;
- `/health` is never limited;
- use Envoy's local rate limit filter (verify reads its `rate_limited` stat).

## Useful commands

    kubectl exec client -- hits -n 12 -r x-local-rate-limit http://envoy:10000/api/items
    kubectl exec client -- hits -n 20 http://envoy:10000/health
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=rate_limit'

When you think you're done: `kdrill verify` (it waits for the bucket to
refill, so it takes about 15 s).

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/local_rate_limit_filter
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/other_features/global_rate_limiting
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/http/http_filters
