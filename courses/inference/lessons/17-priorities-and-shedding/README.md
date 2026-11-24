# Priorities: shed batch traffic when the pool is saturated

Model servers: **simulator** (2 replicas reporting saturation). The endpoint picker is the real llm-d router EPP.

## Concept

An inference pool serves several kinds of traffic: a user waiting on a chat answer, a nightly job summarising a million
documents, an evaluation run. When the pool is saturated (all replicas have long queues or full KV caches),
adding the next request to a queue makes *everybody* slower, including the one who cares. The right response is
to decide who waits and who is turned away: **load shedding by priority**.

The Gateway API Inference Extension models this with an **InferenceObjective**: a named workload with a **priority**
(an integer; higher is more important; **negative means sheddable**) attached to a pool. The client says which objective it
is with a header (`x-gateway-inference-objective`). The endpoint picker, which already knows every replica's queue and
cache from metrics, drops sheddable requests with HTTP 429 when the pool is saturated and keeps serving the rest.
Clients must treat 429 as "retry later with backoff", not as an error to surface.

Priority at this layer is separate from Kubernetes pod priority (lesson 22): that decides which *pods* get GPUs, this decides
which *requests* get a slot.

## The situation

The pool `pool` has two replicas (simulator) whose queues and KV caches are reported as full (a queue of 30 each, cache 95%),
exactly what a flood of batch requests looks like. The gateway calls the picker as in lesson 15. There are no
InferenceObjectives yet, so every request is treated the same and none is shed.

## Your task

Create two InferenceObjectives (apiVersion `llm-d.ai/v1`) that reference the InferencePool `pool`:

- `chat` with a priority of 0 or more (choose 100);
- `batch` with a negative priority (choose -10);

verify then sends requests marked `chat` and `batch` to the saturated pool: all 8 chat requests are served, all 8 batch
requests get 429. It then clears the saturation and requires batch requests to be served again.

## Useful commands

    kubectl get inferenceobjective,inferencepool
    kubectl explain inferenceobjective.spec
    kubectl exec client -- ask -n 8 -c 4 -t 4 -H 'x-gateway-inference-objective: batch' http://edge/v1/chat/completions
    kubectl logs deploy/epp | tail

When you think you're done: `kdrill verify`

## On a real cluster

Set the objective header at the gateway from the authenticated identity or the route (never trust the client); give the
interactive objective a latency SLO; enable flow control to queue rather than reject; and back the policy with
autoscaling (lesson 09) so saturation is the exception. Priorities between *teams* with quotas and fair sharing are
the flow-control fairness policies of the same router.

## Read more

- https://github.com/llm-d/llm-d-router/blob/v1.0.0/pkg/epp/flowcontrol/README.md
- https://gateway-api-inference-extension.sigs.k8s.io/
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429
