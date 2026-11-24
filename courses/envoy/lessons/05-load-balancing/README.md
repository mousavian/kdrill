# Load balancing policies: sticky users with consistent hashing

## Concept

Each cluster has an `lb_policy` that picks a host for each request:

- `ROUND_ROBIN` (default): hosts in turn, weighted by endpoint
  `load_balancing_weight`. Each worker thread keeps its own rotation.
- `LEAST_REQUEST`: pick two hosts at random and use the one with fewer
  outstanding requests ("power of two choices"). Good when requests vary
  a lot in cost, which is why inference gateways start from it.
- `RANDOM`: a random host; avoids synchronised patterns across many proxies.
- `RING_HASH` and `MAGLEV`: **consistent hashing**. The request carries a
  hash; the same hash maps to the same host as long as the host set doesn't
  change, and when a host leaves only the keys it owned move elsewhere.

The hash comes from the **route**, not the cluster: `route.hash_policy`
lists what to hash: a `header`, a `cookie` (Envoy can set one), a
`query_parameter`, or `connection_properties: {source_ip: true}`. Without
a hash, a hashing cluster picks a random host.

Consistent hashing gives "soft" session affinity: user state cached in
one pod, a shard of a cache, a KV-cache prefix on one model server. It's
not a guarantee: scaling, a restarting pod or an ejected host remaps some
users.

More knobs exist (zone-aware routing, priority levels and failover, slow
start for new hosts, `locality_weighted_lb_config`) and appear in Envoy
Gateway as `BackendTrafficPolicy.loadBalancer` (lesson 28).

## The situation

`echo` (3 replicas) sits behind a headless Service, so Envoy sees each pod,
and the cluster uses ROUND_ROBIN. Requests for the cart carry the user in
the header `x-user`.

## Your task

- every request of a user (same `x-user`) reaches the same echo pod (verify
  sends 8 requests for each of 8 users);
- different users spread over at least 2 of the 3 pods;
- requests without `x-user` are still served;
- the cluster `echo` keeps the 3 pods as hosts.

## Useful commands

    kubectl exec client -- hits -p -n 9 http://envoy:10000/cart -H 'x-user: alice'
    kubectl exec client -- hits -p -n 9 http://envoy:10000/cart -H 'x-user: bob'
    kubectl exec client -- curl -s envoy:9901/clusters | grep rq_total
    kubectl edit configmap envoy
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/load_balancing/load_balancers
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#config-route-v3-routeaction-hashpolicy
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/load_balancing/overview
