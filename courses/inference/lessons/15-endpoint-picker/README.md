# Load-aware routing: the Inference Extension endpoint picker

Model servers: **simulator** (3 replicas, one saturated through its admin API). The endpoint
picker is the real llm-d router EPP (v1.0.0).

## Concept

Least-request (lesson 14) counts requests in flight at the proxy. A model server knows
much more about itself: how many requests are waiting for a slot, how full its
KV cache is, which LoRA adapters are loaded, which prompt prefixes it still
has cached. The **Gateway API Inference Extension** standardises how a gateway
uses that:

- an **InferencePool** groups the model-server pods (like a Service with a
  selector) and names an **endpoint picker (EPP)**;
- the gateway's Envoy sends each request to the EPP through the **ext_proc**
  filter (a gRPC callout that sees headers and body);
- the EPP, which scrapes the pods' metrics continuously, scores the candidates
  and answers with a header, **`x-gateway-destination-endpoint: <ip:port>`**; Envoy
  forwards exactly there (and to a fallback if the pick is unusable).

The picker is the "inference router"; the reference implementation lives in the
**llm-d router** project (queue depth, KV-cache utilisation, prefix-cache
affinity, LoRA affinity, request priority and flow control as plugins). Because
the picker only decides *where* a request goes, anything that speaks ext_proc can
be the data plane.

## The situation

Namespace `lab` runs: `llm` (3 simulator replicas), the endpoint picker (Deployment/Service
`epp`) and the InferencePool `llm` it watches, Gateway `edge` and HTTPRoute `llm` to
Service `llm` (plain, no picker yet). One replica (labelled `kdrill.dev/role=busy`) reports 4
running, 40 waiting requests and a 90%-full KV cache; the other two are idle.
In this lab Envoy Gateway v1.9.3 cannot take an InferencePool as a backendRef, so
you wire the picker in with two Envoy Gateway policies (see the envoy
course, lesson 35, for the second one).

## Your task

On the HTTPRoute `llm`:

- an **EnvoyExtensionPolicy** with an `extProc` entry to Service `epp` port 9002, request and
  response bodies in `FullDuplexStreamed` mode, `failOpen` not true;
- a **BackendTrafficPolicy** with `loadBalancer.endpointOverride` extracting the endpoint from the
  header `x-gateway-destination-endpoint`.

Then verify sends 40 requests: all must succeed and the saturated replica gets at
most 2. It then clears the saturation (queue 0, cache 0%) and requires that replica to
take at least 5 of 40, so the picker really follows the metrics, then re-saturates it.

## Useful commands

    kubectl get pods,svc,inferencepool,httproute
    kubectl logs deploy/epp | tail
    kubectl exec client -- curl -s http://epp:9090/metrics | grep -c .          # the picker's own metrics
    kubectl exec client -- ask -n 40 -c 4 -t 4 -w 6 http://edge/v1/chat/completions
    kubectl explain envoyextensionpolicy.spec.extProc
    kubectl explain backendtrafficpolicy.spec.loadBalancer.endpointOverride

When you think you're done: `kdrill verify` (policies take a few seconds to reach Envoy).

## On a real cluster

You install a gateway that supports the Inference Extension, deploy the router chart
(`llm-d-router-gateway`, which creates the picker, the InferencePool and RBAC) and
reference the pool from the HTTPRoute; there are no hand-written ext_proc policies. The picker's
scorers are configured in its `EndpointPickerConfig` (weights per plugin). Real
vLLM replicas expose the metrics the picker reads (`vllm:num_requests_waiting`,
`vllm:kv_cache_usage_perc`); other engines need a metrics mapping.

## Read more

- https://gateway-api-inference-extension.sigs.k8s.io/
- https://github.com/llm-d/llm-d-router
- https://github.com/llm-d/llm-d-router/blob/v1.0.0/docs/architecture.md
- https://gateway.envoyproxy.io/v1.9/tasks/extensibility/ext-proc/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/ext_proc_filter
