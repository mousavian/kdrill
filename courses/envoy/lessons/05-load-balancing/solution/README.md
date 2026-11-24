# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

Two changes:

    route:
      cluster: echo
      hash_policy:
      - header: {header_name: x-user}

    clusters:
    - name: echo
      lb_policy: RING_HASH        # or MAGLEV

The route computes a hash from the request (here the `x-user` header) and
hands it to the cluster's load balancer. RING_HASH places every host many
times on a hash ring (Ketama) and picks the first host clockwise from the
request's hash; MAGLEV builds a fixed lookup table, faster and more even,
slightly less stable when hosts change. Either way, the same user lands on
the same pod as long as the set of hosts doesn't change, and when a pod
goes away only its users move.

Other `hash_policy` sources: `cookie` (Envoy can even generate one with a
`ttl`), `connection_properties: {source_ip: true}`, `query_parameter`,
`filter_state`. Several entries are combined; `terminal: true` stops at the
first one that produced a value. A request with none of them gets a random
host.

Policies at a glance:
- `ROUND_ROBIN` (default): in turn, honours endpoint weights.
- `LEAST_REQUEST`: picks 2 random hosts, takes the one with fewer active
  requests ("power of two choices"). The best default for uneven request
  costs (e.g. LLM inference).
- `RANDOM`: often better than round robin with many Envoys and few requests each.
- `RING_HASH` / `MAGLEV`: consistent hashing for affinity and caches.

Takeaways: affinity is a route-level hash plus a cluster-level hashing LB;
it's best effort, not a guarantee (host changes remap some keys).
