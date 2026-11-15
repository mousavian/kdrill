# Canary a new model version by weight

Model servers: **simulator** (`v1`: 2 replicas, `v2`: 1 replica).

## Concept

Rolling out a new model version (new weights, a new fine-tune, a new engine
or quantisation) is risky in a way that ordinary code deploys are not: the new
version may be *wrong* without ever crashing (worse answers, more refusals,
longer outputs that cost more GPU time), and you only find out under real
traffic. The remedy is the usual one, a **canary**: run the new version next to
the old one and give it a small share of the traffic, watch, then grow it.

The Gateway API does it with **weighted backendRefs**: in one rule, each
backend has a `weight`, and the gateway picks a backend per request in that
proportion. Combined with a **header match** you also get an explicit override
for testers (`x-canary: always`). Rules are evaluated by specificity: a rule
with a header match beats one without. Both versions are separate
Deployments and Services, so each can have its own replica count, GPU type and probes
(Part D), and rollback is changing one number.

For the model name inside the request (rather than the URL) the Inference
Extension offers `InferenceModelRewrite`: clients keep asking for `chat`
and the router maps 90% of the requests to `chat-v1` and 10% to `chat-v2`.

## The situation

Gateway `edge`, Services `v1` (2 replicas) and `v2` (1 replica), and an HTTPRoute `llm` whose only rule
sends **all** traffic to `v2`: the new version was switched on for everybody.

## Your task

- one rule with weighted backends, `v1` much heavier than `v2` (at least 4 to 1; 90/10 is the target), both with weight >= 1;
- a rule for requests with the header `x-canary: always` that goes to `v2` only;
- with 60 requests, 1 to 15 reach `v2` and all are answered; 10 of 10 requests with the header reach `v2`.

## Useful commands

    kubectl exec client -- ask -n 60 -c 4 -t 4 -w 6 http://edge/v1/chat/completions
    kubectl exec client -- ask -n 10 -H 'x-canary: always' http://edge/v1/chat/completions
    kubectl explain httproute.spec.rules.backendRefs
    kubectl get httproute llm -o yaml

When you think you're done: `kdrill verify`

## On a real cluster

Combine canary weights with automated analysis (Argo Rollouts, Flagger) on model-quality
metrics; use shadow traffic (`RequestMirror`) to compare answers without serving
them; and give each version its own InferencePool so each keeps load-aware routing.

## Read more

- https://gateway-api.sigs.k8s.io/guides/traffic-splitting/
- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/#httpbackendref
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-traffic-splitting/
- https://github.com/llm-d/llm-d-router (InferenceModelRewrite)
