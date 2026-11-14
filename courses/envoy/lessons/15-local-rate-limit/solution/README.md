# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

The filter in the chain (no bucket, so it does nothing by default):

    http_filters:
    - name: envoy.filters.http.local_ratelimit
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
        stat_prefix: http_local_rate_limiter
    - name: envoy.filters.http.router

and the bucket on the `/api/` route via `typed_per_filter_config`
(`token_bucket {max_tokens: 5, tokens_per_fill: 5, fill_interval: 10s}`,
`filter_enabled` and `filter_enforced` at 100%, plus the response header).

How the token bucket works: it starts full (5 tokens); each request takes
one; every 10 s it gets 5 tokens back, never more than `max_tokens`. So a
client can burst up to 5 and then gets 5 per 10 s. A request that finds the
bucket empty is answered by Envoy with 429 (access log flag `RL`) and never
reaches the backend.

Notes:
- `filter_enabled` (evaluate) and `filter_enforced` (actually reject) let
  you roll out in shadow mode first: enabled 100%, enforced 0%, and watch
  the `rate_limited` stat.
- The bucket is per Envoy process (shared by its workers). Behind 3 Envoy
  replicas, the effective limit is 3x. For a limit across the fleet, or per
  user/API key at scale, use **global rate limiting**: the
  `envoy.filters.http.ratelimit` filter calls a rate limit service
  (envoyproxy/ratelimit with Redis). Envoy Gateway runs that service for you
  when you configure a global limit (lesson 30 uses the local kind).
- `descriptors` give separate buckets per header value (e.g. per API key)
  within the local filter.

Takeaways: local rate limits are cheap and need nothing else, ideal as a
safety cap per instance; per-client fairness across a fleet needs a global
limiter.
