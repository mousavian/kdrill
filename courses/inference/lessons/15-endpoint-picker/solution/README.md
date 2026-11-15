# Solution

From the lesson directory:

    kubectl apply -f solution/wiring.yaml

Two policies on the HTTPRoute `llm`:

1. **EnvoyExtensionPolicy `epp`**: Envoy's ext_proc filter calls the endpoint picker (Service
   `epp`, port 9002, plain gRPC) for every request, in `FULL_DUPLEX_STREAMED` body mode (the only
   mode the llm-d picker supports: it sees the request body, for the model name and prompt, and the
   response).
2. **BackendTrafficPolicy `pick`**: `endpointOverride` makes Envoy's load balancer use the
   `ip:port` the picker puts in the header `x-gateway-destination-endpoint` (Envoy's
   `override_host` policy), with LeastRequest as the fallback when the header is missing.

What the picker does with each request: it keeps a live view of every pod in the
InferencePool, scraping each pod's `/metrics` every 200 ms in this lab (vLLM names:
`num_requests_waiting`, `num_requests_running`, `kv_cache_usage_perc`), runs its
scorers (here `queue-scorer` and `kv-cache-utilization-scorer`, weights 2 and 2; the
default llm-d profile adds prefix-cache affinity), and answers with the
best pod. The saturated pod (queue 40, cache 90%) scores worst on both, so
nearly all traffic goes to the other two; when it recovers its score recovers and so does its share.

Why this is not "InferencePool as a backendRef": in the Gateway API Inference Extension an
HTTPRoute references the **InferencePool** directly (`backendRefs: [{group:
inference.networking.k8s.io, kind: InferencePool, name: ...}]`) and the gateway
implementation wires the picker in for you. Envoy Gateway v1.9.3 answers such a route with
`ResolvedRefs=False / InvalidKind`; that support comes from Envoy AI Gateway (an extension of Envoy
Gateway) or from other gateways (kgateway, Istio, agentgateway, NGINX Gateway
Fabric). The two policies here are what those implementations generate. The
InferencePool object is still useful: the picker reads it to find the pods and the port.
