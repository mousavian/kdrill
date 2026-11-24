# One endpoint, several models: route by the model in the request body

Model servers: **simulator** (`small`: 2 replicas, `large`: 1 replica, slower).

## Concept

With the OpenAI-compatible API every request goes to the same URL
(`/v1/chat/completions`) and the model is a **field in the JSON body**:
`{"model": "large", ...}`. A platform serving several models behind one hostname
(and one API key) therefore needs a gateway that routes on the body.
HTTP routing normally cannot see it: Gateway API matches on host, path,
headers, query parameters and method.

The pattern is *body-based routing*:

1. a filter in the proxy **buffers the request body** (small: a prompt, not
   the response), extracts the model name and writes it to a **header**;
2. ordinary route rules match that header and pick the backend (a Service per
   model, or an InferencePool per model, lesson 15).

The two traps: **spoofing** (the filter must overwrite the header; if clients can
set `x-model` themselves they can pick any backend, bypassing authorisation) and
**buffering** (only the request may be buffered; streaming responses,
lesson 05, must still flow). The Gateway API Inference Extension ships a BBR
component for this, Envoy AI Gateway does it natively; in this lab Envoy
Gateway's `EnvoyExtensionPolicy` runs a Lua filter inline.

## The situation

Gateway `edge`, services `small` (model `small`) and `large` (model `large`),
and an HTTPRoute `llm` with a single catch-all rule that sends everything to `small`: a request for
`large` is answered with a 404 by the small server, which does not know it.

## Your task

- an EnvoyExtensionPolicy with an inline Lua script on the Gateway that sets the header
  `x-model` from the body's `model`;
- HTTPRoute rules that send `x-model: small` to Service `small` and `x-model: large` to
  Service `large`, and a last catch-all rule that answers 404 itself (an `HTTPRouteFilter` with a
  `directResponse`) so that unknown models are not forwarded anywhere;
- a client-sent `x-model` header is ignored (the body decides);
- an unknown model gets 404 from the gateway itself (no `x-inference-pod` header on the answer); a streamed request for `large` still streams.

## Useful commands

    kubectl exec client -- ask -m large -n 6 http://edge/v1/chat/completions
    kubectl exec client -- ask -m small -n 6 -H 'x-model: large' http://edge/v1/chat/completions
    kubectl explain envoyextensionpolicy.spec.lua
    kubectl get envoyextensionpolicy,httproute

`ask` prints which pod answered (`x-inference-pod`). When you think you're done:
`kdrill verify` (a new policy needs a few seconds to reach Envoy).

## On a real cluster

Use the Gateway API Inference Extension's body-based router, or the AI gateway of
your platform (Envoy AI Gateway, kgateway, Istio + AI extensions), which also
parse the JSON properly, rewrite model aliases and attach authentication per
model. Per-model InferencePools (with an endpoint picker each) replace the plain
Services used here.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/extensibility/lua/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#envoyextensionpolicy
- https://gateway-api-inference-extension.sigs.k8s.io/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/lua_filter
