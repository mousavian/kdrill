# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml

    rateLimit:
      type: Local
      local:
        rules:
        - clientSelectors:
          - headers: [{name: x-plan, value: gold}]
          limit: {requests: 30, unit: Minute}
        - limit: {requests: 5, unit: Minute}

Envoy Gateway configures Envoy's `local_ratelimit` filter (lesson 15) on
the route: a default token bucket of 5 per minute, plus a descriptor bucket
of 30 per minute for requests whose `x-plan` header is `gold`. Requests
over the limit get 429 from Envoy and never reach the backend; the
`rate_limited` stat counts them.

Notes:
- **Local** = per Envoy replica: with 3 Gateway replicas the real limit is
  3x. **Global** (`type: Global`) keeps counters in Envoy's rate limit
  service backed by Redis, which Envoy Gateway deploys once you configure
  `rateLimit` in its EnvoyGateway config (Redis URL). Global rules can also
  use `type: Distinct` selectors: one bucket per distinct header value or
  client IP ("100 per minute per API key"). That needs Redis, which this
  lab leaves out to save memory.
- Header-based plans are only as trustworthy as the header: in production
  derive them from an authenticated identity (JWT claim to header,
  lesson 31) rather than a client-supplied value.
- Buckets refill per unit; within the lab you may need to wait a minute
  between verify runs if you exhaust the gold budget.
