# Solution

From the lesson directory:

    kubectl apply -f solution/gateway.yaml

Two changes:

    # HTTPRoute llm
    timeouts:
      request: 0s            # was 3s: no limit on the whole response

    # ClientTrafficPolicy edge
    timeout:
      http:
        streamIdleTimeout: 120s   # was 2s: a stream may be silent this long

Why both: for a streamed completion the HTTP request is one long response. The
route's `request` timeout counts from the request until the response is complete,
so any generation longer than 3 s was cut mid-token. The stream idle timeout
counts time with no bytes either way; the model's 3 s "thinking" before the first
token is silence, so a 2 s idle timeout cut the stream before it began. Pick
values from your slowest realistic generation (a long prompt can take tens of
seconds to prefill; a 4000-token answer at 30 tokens/s takes over two minutes),
not from web-page defaults.

Streaming itself needed no setting: Envoy passes Server-Sent Events through
unbuffered unless a filter asks it to buffer (lesson 13 buffers the *request*
body to read the model name, which is fine, the response still streams).
