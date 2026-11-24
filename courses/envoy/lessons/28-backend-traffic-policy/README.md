# BackendTrafficPolicy: sticky load balancing and passive health checks

## Concept

Everything in lessons 04-10 that describes how Envoy treats a backend
(load balancing policy, active and passive health checks, circuit breakers,
retries, timeouts, connection settings) is expressed in Envoy Gateway as a
**BackendTrafficPolicy**, attached to a Gateway or a route:

- `loadBalancer`: `RoundRobin`, `LeastRequest`, `Random`, or
  `ConsistentHash` with `consistentHash.type` `SourceIP`, `Header`,
  `Headers`, `Cookie` or `QueryParams` (Envoy Gateway uses Maglev);
  `slowStart` for new endpoints; zone-aware routing.
- `healthCheck.passive`: outlier detection (`consecutive5XxErrors`,
  `consecutiveGatewayErrors`, `interval`, `baseEjectionTime`,
  `maxEjectionPercent`); `healthCheck.active`: HTTP/TCP/gRPC probes.
- `circuitBreaker`, `retry`, `timeout`, `connection`, `dns`, `rateLimit`
  (lesson 30), `faultInjection`, `compression`, ...

Because Envoy Gateway programs endpoints by EDS (pod IPs), all of these
work per pod, exactly as in Part A.

A policy that changes a cluster (load balancer, outlier detection, circuit
breakers) makes Envoy Gateway send a new version of that cluster. Envoy
**warms** it (waits for its endpoints over EDS) before switching, which
here takes up to about 15 s: `config_dump?resource=dynamic_warming_clusters`
shows it in the meantime. Route-level changes apply at once.

Policy rules worth remembering: the most specific target wins (route rule
over route over Gateway listener over Gateway) unless `mergeType` asks for
merging; two policies of the same kind on the same target conflict; every
policy reports `Accepted` (or why not) per Gateway in `status.ancestors`.

## The situation

Gateway `edge`, HTTPRoute `cart` (`shop.lab/cart` to the Service `echo`).
Behind `echo`: three echo pods and the pod `sick` (503 to everything).
The cart keeps per-user state, identified by the header `x-user`.

## Your task

Create one BackendTrafficPolicy, attached to the HTTPRoute `cart` and
Accepted, so that:

- requests are hashed on `x-user`: each user's requests go to one pod, and
  users spread over at least 2 pods;
- passive health checking ejects a pod after 3 consecutive 5xx (keep
  `baseEjectionTime` at 30 s or more): after verify's warm-up of 40
  requests, the sick pod is ejected and nobody gets errors anymore;
- the sick pod stays behind the Service.

## Useful commands

    kubectl exec client -- hits -p -n 6 http://edge/cart -H 'Host: shop.lab' -H 'x-user: alice'
    kubectl explain backendtrafficpolicy.spec.loadBalancer.consistentHash
    kubectl get backendtrafficpolicy -o yaml
    kubectl port-forward deploy/edge 19000 &  curl -s localhost:19000/clusters | grep health_flags

When you think you're done: `kdrill verify` (right after a change it
waits up to 25 s for the new cluster to become active).

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/load-balancing/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/circuit-breaker/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#passivehealthcheck
