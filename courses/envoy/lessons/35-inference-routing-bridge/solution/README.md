# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml

    loadBalancer:
      type: LeastRequest
      endpointOverride:
        extractFrom:
        - header: x-gateway-destination-endpoint

Envoy Gateway configures the cluster with Envoy's `override_host` load
balancing policy (look for `envoy.load_balancing_policies.override_host` in
`config_dump?resource=dynamic_active_clusters`): if the request carries an
endpoint (`ip:port`) that is a healthy member of this cluster, use it;
otherwise use the fallback policy, here least-request. An address outside
the cluster is never connected to, so a client can't use the header to
reach arbitrary pods.

How this becomes inference routing (the next course):
- The **Gateway API Inference Extension** adds an **InferencePool**
  (the model-server pods, like a Service with a picker attached) usable as
  an HTTPRoute backendRef, and objectives/priorities per model or workload.
- An **endpoint picker (EPP)** runs next to the pool. The Gateway calls it
  for every request through Envoy's **ext_proc** filter (external
  processing: a gRPC service that sees headers and body). The EPP reads the
  request (model name, LoRA adapter, prompt), scrapes each model server's
  metrics (queue length, KV-cache utilisation, loaded adapters, prefix-cache
  hits), picks the best pod, and returns it in
  `x-gateway-destination-endpoint`. Envoy routes exactly there: the
  mechanism you just configured.
- **Body-based routing** pulls the `model` field out of an OpenAI-style JSON
  body into a header, so ordinary HTTPRoute header matches can choose a pool
  per model.
- **Envoy AI Gateway** builds on Envoy Gateway for LLM traffic: a unified
  API across providers (OpenAI, Bedrock, Vertex, self-hosted), credential
  injection, provider fallback, and rate limits counted in tokens rather
  than requests, plus InferencePool support.

Why not just least-request? A model server's cost per request varies by
orders of magnitude (prompt and output length), and the best pod is often
the one that already has the prompt prefix or adapter in memory. Only
something that reads model-server metrics and the request can know that;
Envoy provides the hook.
