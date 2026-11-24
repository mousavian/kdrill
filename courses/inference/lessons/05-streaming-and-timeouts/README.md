# Streaming and timeouts: do not cut long generations

Model server: **simulator** (3 s time to first token, then 10 tokens/s).

## Concept

Chat UIs show an answer as it is written. The server achieves that with
`"stream": true`: instead of one JSON document it sends **Server-Sent Events**,
a response that stays open and carries one `data: {...}` line per few tokens,
ending with `data: [DONE]`. For HTTP infrastructure that is a single very long
response, and every timeout in the path now matters:

- a **request timeout** (HTTPRoute `timeouts.request`, an Ingress annotation, a
  cloud load balancer's 60 s default) limits the time to the *last* byte;
- an **idle/stream-idle timeout** closes a connection that carries no bytes. An
  LLM is silent while it processes the prompt (prefill: seconds for a long
  prompt, much longer for a 100k-token document) before the first token appears;
- **buffering** anywhere (a gzip filter, a proxy buffering responses, a CDN)
  turns a stream back into one late blob.

The two metrics users feel are **time to first token** (TTFT: queueing +
prefill) and **time per output token** (decode speed). A gateway should set
timeouts from them: `TTFT_p99 + max_tokens x time_per_token`, with headroom. The
usual symptom of getting it wrong is a response that stops mid-sentence at a
suspiciously round number of seconds.

All traffic in this lab is sent from the in-cluster client: `kubectl
port-forward` terminates long-lived streams, so do not test streaming through it.

## The situation

A model server `llm` (simulator, TTFT 3 s, 100 ms per token), Gateway `edge`
(Envoy Gateway), HTTPRoute `llm` with `timeouts.request: 3s`, and a
ClientTrafficPolicy with `streamIdleTimeout: 2s`. `ask -s` prints the chunk count
and the time to the first and last chunk.

## Your task

Change the gateway configuration (not the model) so that:

- a streamed request for 30 tokens returns 200 with all 30 token chunks;
- the chunks arrive spread over time (last at least 2 s after the first), and the first
  one after at least 2.5 s (the model's own wait was not cut);
- a non-streamed request still works.

## Useful commands

    kubectl exec client -- ask -s -t 30 -w 40 http://edge/v1/chat/completions
    kubectl get httproute,clienttrafficpolicy
    kubectl explain httproute.spec.rules.timeouts
    kubectl explain clienttrafficpolicy.spec.timeout.http

When you think you're done: `kdrill verify` (a new policy needs a few seconds to reach Envoy).

## On a real cluster

Behind a cloud load balancer, raise its idle timeout too (AWS ALB/NLB: up to
4000 s; GCP: backend service timeout). If a service mesh sidecar sits in the path
it has its own idle and request timeouts. Clients should handle a cut stream
(reconnect with the partial text); gateways such as Envoy AI Gateway can also
enforce per-request token limits.

## Read more

- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/#httproutetimeouts
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-timeouts/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#timeout
- https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
