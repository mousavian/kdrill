# Capstone: a two-model service with five planted faults

Model servers: **simulator**. Endpoint picker, KEDA, Envoy Gateway: the real ones.

## Concept

This lesson uses everything from Parts A to C at once. A gateway serves two models behind one URL:

- `chat` (3 requests at a time per replica, 10 s load time, answers of ~2 s) with load-aware routing
  (the endpoint picker, lesson 15) and autoscaling on in-flight requests (lesson 09);
- `summarize` (a second model, plain Service);
- model routing from the request body (lesson 13) with a 404 for unknown models.

Production incidents are rarely one fault; they are several small ones that hide each other (pods that never
become ready make routing look broken; a routing typo makes the autoscaler look broken). Work from the
outside in: follow a request through gateway, route, picker, pod, and autoscaler, and
check status fields (`kubectl describe`, conditions, events) before changing anything.

A useful order: **is it up?** (pods ready and stable: restarts mean probes or crashes), **is it reachable?** (routes accepted and resolved, the right
backend per model), **is it balanced?** (does the picker's answer reach Envoy and is it obeyed), **does it scale?** (what signal the
autoscaler reads and what it is allowed to do) and **does it survive change?** (what happens to requests when pods are replaced).
Each of the five faults lives in one of those questions.

## The situation

Everything is deployed and "mostly works". There are five independent faults, one in each of: model routing, chat's
probes, chat's shutdown behaviour, the autoscaler, and the endpoint picker's wiring. The simulators and the
aggregator, picker and gateway Deployments themselves are fine: fix **configuration** (routes, probes, lifecycle,
ScaledObject, policies), not the model servers' arguments.

## Your task

Make `kdrill verify` pass. It checks configuration (see the hints for the lessons each fault comes from), then end to end:

- 6 chat and 6 summarize requests are answered by the right pods, unknown models get a 404 from the gateway;
- with one chat replica reporting a saturated KV cache (verify makes it so), 30 chat requests go almost entirely elsewhere;
- with 9 users, chat scales to at least 3 ready replicas;
- 60 chat requests sent during a `rollout restart` all answer 200.

**The end-to-end part takes about three minutes**, and it only runs once the configuration checks pass.

## Useful commands

    kubectl get pods,svc,httproute,scaledobject,hpa
    kubectl describe httproute summarize
    kubectl get backendtrafficpolicy,envoyextensionpolicy
    kubectl logs deploy/epp | tail
    kubectl exec client -- ask -m chat -n 6 http://edge/v1/chat/completions
    kubectl exec client -- curl -s http://aggregator/

When you think you're done: `kdrill verify`

## On a real cluster

The same stack: Gateway API Inference Extension (or llm-d router), KEDA/Prometheus autoscaling, vLLM probes and drain,
GPU nodes. The investigation order carries over; add the GPU side (nvidia-smi / DCGM, node pressure) and the
node autoscaler.

## Read more

- https://gateway-api.sigs.k8s.io/guides/http-routing/
- https://llm-d.ai/
- https://keda.sh/docs/2.21/
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
