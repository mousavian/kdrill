The local rate limit is an HTTP filter. It must be in the HCM's
`http_filters` list *before* the router:

    - name: envoy.filters.http.local_ratelimit
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
        stat_prefix: http_local_rate_limiter

Configured like this, without a `token_bucket`, it limits nothing. Each
route can bring its own configuration with `typed_per_filter_config`.
---
On the `/api/` route (next to `match` and `route`):

    typed_per_filter_config:
      envoy.filters.http.local_ratelimit:
        "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
        stat_prefix: api
        token_bucket: {max_tokens: 5, tokens_per_fill: 5, fill_interval: 10s}
        filter_enabled:  {runtime_key: api_rl_enabled,  default_value: {numerator: 100, denominator: HUNDRED}}
        filter_enforced: {runtime_key: api_rl_enforced, default_value: {numerator: 100, denominator: HUNDRED}}
        response_headers_to_add:
        - header: {key: x-local-rate-limit, value: "true"}

`filter_enabled` and `filter_enforced` default to 0%: without them nothing
is limited.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
