# Solution

From the lesson directory:

    kubectl apply -f solution/echo-pods.yaml
    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

`echo-pods` is a headless Service (`clusterIP: None`) for the same pods. Its
DNS name returns one A record per ready pod, so the STRICT_DNS cluster now
has three hosts, Envoy's round robin spreads requests across them, and
`/clusters` shows per-pod counters. (Turning the Service `echo` itself
headless works too.)

    - name: echo
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN
      dns_refresh_rate: 2s
      respect_dns_ttl: false
      load_assignment: ... {address: echo-pods, port_value: 80}

Why the ClusterIP version was skewed: Envoy sees a single host, so all of
its load balancing (round robin, least request, hashing, health checks,
outlier detection, per-host circuit breakers) operates on one fake host.
kube-proxy picks a backend pod per TCP connection, and Envoy keeps a few
long-lived upstream connections (one pool per worker thread), so a few pods
get almost everything. With HTTP/2 or gRPC to the upstream it's worse:
one connection carries everything.

Discovery types in short:
- `STATIC`: fixed IPs in the config.
- `STRICT_DNS`: resolve periodically, every address is a host (headless Services).
- `LOGICAL_DNS`: resolve on new connections, use only the first address
  (large external services behind DNS round robin).
- `EDS`: a control plane pushes the endpoints (Envoy Gateway and Istio
  watch EndpointSlices and send pod IPs this way).
- `ORIGINAL_DST`: send to the destination the connection (or a header) names.

Takeaways: for Envoy to balance, health-check or eject pods, it must see
pods. In Kubernetes that means a headless Service or EDS, never the ClusterIP.
