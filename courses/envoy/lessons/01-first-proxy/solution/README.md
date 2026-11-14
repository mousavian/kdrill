# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy
    kubectl rollout status deploy/envoy

The added cluster:

    clusters:
    - name: echo
      type: STRICT_DNS
      connect_timeout: 1s
      load_assignment:
        cluster_name: echo
        endpoints:
        - lb_endpoints:
          - endpoint:
              address:
                socket_address: {address: echo, port_value: 80}

How a request flows now: the client connects to the listener `main`
(0.0.0.0:10000). Its only filter chain has one network filter, the HTTP
connection manager (HCM), which parses HTTP and runs its HTTP filters. The
last HTTP filter, the router, looks up the route table `local_route`: the
virtual host `all` matches any Host header, the route `prefix: /` matches
any path, so the request goes to the cluster `echo`. The cluster's load
balancer picks a host (the address `echo` resolved to) and the router
sends the request over a pooled upstream connection.

Things to notice in the answer the backend printed:

- `X-Request-Id`, `X-Forwarded-Proto` and `X-Envoy-Expected-Rq-Timeout-Ms`
  were added by Envoy (the HCM and the router). The default route timeout is
  15 s.
- `RemoteAddr` is the Envoy pod, not the client: Envoy is a full proxy with
  its own upstream connection.

Takeaways: listener -> filter chain -> HCM -> route config -> cluster ->
endpoints. Envoy validates references at start and exits on a bad static
config, so `kubectl logs` is the first place to look.
