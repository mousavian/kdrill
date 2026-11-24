# Protecting the fleet: a rate limit per client

Model server: **simulator** (2 concurrent requests, about 0.7 s per answer).

## Concept

A model server has a fixed number of slots; whoever fills them decides everyone's latency. One client with a retry loop, a batch job
with 200 workers or a leaked API key can starve all others, and a GPU is too expensive to over-provision against that.
The classic protection sits at the gateway: **rate limiting**.

- a **token bucket** per client: it holds up to N tokens and refills at R per second; each request takes a token; no token, no
  request: HTTP **429** (and a `Retry-After` hint where supported). Rejection at the gateway is nearly free, unlike queueing on a GPU;
- **who is a client?** The limit is keyed on something that identifies one: an API key, a JWT subject, a source IP. Envoy
  Gateway calls the selector `clientSelectors`; with `type: Distinct` on a header every different value gets its own bucket;
- **local** limits live inside each Envoy instance; **global** limits are coordinated by a shared service (Redis).

Requests per second is a blunt unit for LLMs, whose cost is in **tokens**: a request can be 10 tokens or 100 000. Real budgets are
tokens per minute, counted from the response's usage field (and from the prompt on the way in), which an AI gateway does for you. A request
rate limit still stops the worst floods, and it is the simplest layer to add first.

## The situation

Gateway `edge` and HTTPRoute `llm` in front of one model server. A Deployment `mallory` runs 8 users that send requests with the header
`x-api-key: mallory` as fast as they can, so the two model slots are always busy and every other client queues behind them.

## Your task

Attach a BackendTrafficPolicy to the HTTPRoute `llm` with a **local** rate limit that:

- is keyed on the `x-api-key` header with `type: Distinct` (one budget per key);
- allows between 1 and 3 requests per **Second** per key.

verify then checks the effect: mallory, sending 24 requests at once, gets at least 14 of them rejected with 429; alice's six
requests one after another all succeed with a median response time of at most 1.6 s while mallory is still flooding; requests without an API key
are not rejected.

## Useful commands

    kubectl exec client -- ask -v -n 6 -t 10 -w 14 -H 'x-api-key: alice' http://edge/v1/chat/completions
    kubectl explain backendtrafficpolicy.spec.rateLimit.local.rules
    kubectl get backendtrafficpolicy
    kubectl logs deploy/mallory      # mallory's load generator (it prints nothing until it ends)

When you think you're done: `kdrill verify` (the policy needs a few seconds to reach Envoy).

## On a real cluster

Authenticate first (JWT or API-key SecurityPolicy) and key the limit on the authenticated identity; use global rate limits with
Redis for several gateway replicas; count tokens (AI gateway, or cost-based limits from ext_proc metadata); give paying tiers
bigger budgets with extra rules; and return `Retry-After` so well-behaved clients back off.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/local-rate-limit/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/global-rate-limit/
- https://aigateway.envoyproxy.io/docs/capabilities/traffic/usage-based-ratelimiting/
- https://en.wikipedia.org/wiki/Token_bucket
