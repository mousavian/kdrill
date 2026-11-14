# Rate limiting with BackendTrafficPolicy (local)

## Concept

Envoy Gateway's BackendTrafficPolicy has a `rateLimit` section with two
flavours, matching lesson 15:

- **Local**: token buckets inside each Envoy replica, no dependencies.
- **Global**: Envoy asks a central rate limit service (envoyproxy/ratelimit
  with Redis) so limits hold across replicas and per client key.

Limits are **rules**. Each rule has a `limit` (`requests` per `unit`) and
optional `clientSelectors` that pick which requests count against it:
headers (Exact or RegularExpression; `Distinct` for global, one bucket per
value), `sourceCIDR`, `methods`, `path`. A rule without selectors is the
default bucket. Requests over a limit get **429** from Envoy, optionally
with `x-ratelimit-*` headers.

Rejections are cheap: Envoy answers 429 itself, so the backend never sees
the excess. Clients should treat 429 as "back off and retry later", ideally
honouring a `Retry-After` or `x-ratelimit-reset` header.

This is the gateway-level protection to put in front of any expensive
backend: a cap per instance (local) and fairness per customer (global).
For LLM backends, the Envoy AI Gateway extends this to token-based limits
(count tokens, not requests), lesson 35.

## The situation

Gateway `edge` and HTTPRoute `api` (`api.lab`) to the `api` backend, with
no limits.

## Your task

Create a BackendTrafficPolicy on the HTTPRoute `api` (Accepted, type
Local) so that:

- requests without a plan may make at most 5 requests per minute (a burst
  of 12 gets at most 5 through; the rest get 429);
- requests with the header `x-plan: gold` have their own budget of 30 per
  minute (a burst of 12 all succeed).

## Useful commands

    kubectl exec client -- hits -n 12 http://edge/items -H 'Host: api.lab'
    kubectl exec client -- hits -n 12 http://edge/items -H 'Host: api.lab' -H 'x-plan: gold'
    kubectl explain backendtrafficpolicy.spec.rateLimit.local
    kubectl get backendtrafficpolicy -o yaml

When you think you're done: `kdrill verify`. The buckets refill once a
minute; if you have used up a budget while testing, wait a minute.

## On a real cluster

Use global rate limiting with a Redis your platform runs (the lab leaves
it out to save memory), and select on authenticated identities rather than
headers a client can set.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/local-rate-limit/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/global-rate-limit/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#ratelimitrule
