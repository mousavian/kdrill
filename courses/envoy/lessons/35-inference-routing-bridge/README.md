# Bridge to AI inference routing: endpoint picking

## Concept

LLM inference breaks the assumptions behind the load balancers of lessons
05 and 28. Requests differ wildly in cost (a 50-token prompt vs a
20 000-token one), servers have state that matters (which prompt prefixes
are in the KV cache, which LoRA adapters are loaded), and the right signal
is in model-server metrics (queue depth, KV-cache utilisation), not in
connection counts.

The **Gateway API Inference Extension** adds that intelligence without
replacing the proxy:

- an **InferencePool** resource groups the model-server pods and is used as
  a backendRef in an HTTPRoute;
- an **endpoint picker (EPP)** watches the pool's metrics. For every
  request, the Gateway's Envoy asks it (via the **ext_proc** filter, a gRPC
  callout that can read headers and body) which pod to use;
- the EPP answers with the header **`x-gateway-destination-endpoint:
  <ip:port>`**, and Envoy's load balancer sends the request to exactly that
  pod, falling back to normal balancing if the pick is unusable.

That last step is plain Envoy: the `override_host` load balancing policy.
Envoy Gateway exposes it as `BackendTrafficPolicy.loadBalancer.
endpointOverride`. In this lesson you configure that mechanism and verify
plays the picker by setting the header itself. The EPP, InferencePool and
real model servers come in the inference course; they need far more
memory than this lab has.

Further up the stack, **Envoy AI Gateway** (built on Envoy Gateway) adds
LLM-specific features: one API across model providers, provider fallback,
token-based rate limiting, and body-based routing by model name.

## The situation

Three pods of `llama` (stand-ins for model servers; they answer with
`Name: llama-3-8b` and their pod name) behind the Service `llama`; an
unrelated pod `admin`; Gateway `edge` and HTTPRoute `llm` (`llm.lab/v1`)
to `llama`.

## Your task

Attach a BackendTrafficPolicy to the HTTPRoute `llm` (Accepted) so that:

- a request with `x-gateway-destination-endpoint: <pod-ip>:80` naming a
  llama pod is served by exactly that pod;
- a header naming an address outside the pool (the admin pod) is ignored:
  the llama pool serves the request;
- without the header, least-request balancing (`type: LeastRequest`)
  spreads requests over the pool.

## Useful commands

    kubectl get pods -l app=llama -o wide
    kubectl exec client -- hits -p -n 10 http://edge/v1/chat/completions -X POST -H 'Host: llm.lab' -H 'x-gateway-destination-endpoint: <pod-ip>:80'
    kubectl exec client -- hits -p -n 30 http://edge/v1/chat/completions -X POST -H 'Host: llm.lab'
    kubectl explain backendtrafficpolicy.spec.loadBalancer.endpointOverride

When you think you're done: `kdrill verify` (right after a change it
waits up to 25 s for the new cluster to become active).

## On a real cluster

A client must never choose the endpoint itself: in a real inference
gateway the EPP sets the header after the request arrived (and strips any
client-supplied value). The lab lets the client set it to show the Envoy
mechanism in isolation.

## Read more

- https://gateway-api-inference-extension.sigs.k8s.io/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#endpointoverride
- https://aigateway.envoyproxy.io/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/ext_proc_filter
