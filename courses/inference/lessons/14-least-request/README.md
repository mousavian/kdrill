# Why round-robin is bad for LLMs: least-request balancing

Model servers: **simulator** (3 replicas, one made slow).

## Concept

Kubernetes Services balance connections without looking at the work behind
them. A gateway can do better. The common policies:

- **Round-robin**: next backend in a cycle. Fair in request *count*; fine when
  every request costs the same.
- **Random**: statistically the same, without coordination.
- **Least-request**: send to the backend with the fewest requests in flight
  (Envoy samples two at random and takes the less loaded one: "power of two
  choices", cheap and nearly as good as the exact minimum).
- **Consistent hash**: same key (user, session, prompt prefix) goes to the same
  backend, to reuse caches; the opposite goal.

LLM traffic is unusually uneven. One request can cost 100 times another
(prompt length x answer length), a replica can degrade for a while (a long
prefill ahead of the queue, a throttled GPU, a cold KV cache), and a request
cannot be cancelled and retried elsewhere cheaply once generation began.
Round-robin keeps feeding the slow replica a full share; its queue grows,
and the whole service's tail latency follows it. Least-request needs nothing but the
proxy's own count of requests in flight and fixes the worst of it. Lesson 15
goes further by reading the server's metrics.

## The situation

Gateway `edge`, HTTPRoute `llm` to Service `llm` (3 replicas) and a
BackendTrafficPolicy `balance` set to `RoundRobin`. One replica (labelled
`kdrill.dev/role=slow`) takes 3 s to produce its first token; the others 0.1 s. `ask` prints how many
requests each pod answered.

## Your task

Change the policy's load balancing to `LeastRequest`, so that when 12 users send 120
requests, all are answered and the slow replica serves at most 20% of them; it must stay
ready and behind the Service.

## Useful commands

    kubectl exec client -- ask -n 120 -c 12 -t 6 -w 10 http://edge/v1/chat/completions
    kubectl get pods -L kdrill.dev/role
    kubectl get backendtrafficpolicy
    kubectl explain backendtrafficpolicy.spec.loadBalancer.type

When you think you're done: `kdrill verify` (the policy needs a few seconds to reach Envoy).

## On a real cluster

The same policies exist in every Envoy-based gateway (Istio `loadBalancer.simple: LEAST_REQUEST`,
Envoy Gateway as here). Outlier detection (eject a replica that returns errors) and
active health checks complement it; neither replaces a picker that understands queues
and KV cache.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/load-balancing/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/load_balancing/load_balancers#weighted-least-request
- https://www.eecs.harvard.edu/~michaelm/postscripts/tpds2001.pdf
