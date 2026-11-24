# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    listener_filters:
    - name: envoy.filters.listener.tls_inspector
      typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.listener.tls_inspector.v3.TlsInspector}
    filter_chains:
    - filter_chain_match: {server_names: ["a.lab"]}
      filters:
      - name: envoy.filters.network.tcp_proxy
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
          stat_prefix: site_a
          cluster: site-a
    - filter_chain_match: {server_names: ["b.lab"]}
      filters: [ same, cluster site-b ]

The tls_inspector peeks at the unencrypted ClientHello (SNI, ALPN) and
leaves the bytes in place. The matching chain's tcp_proxy opens a TCP
connection to the cluster and copies bytes both ways. The TLS session runs
end to end between client and backend: Envoy holds no certificate and sees
no HTTP.

What you give up at L4: no HTTP routing, retries, header edits or
per-request stats; the access log has one entry per connection; load
balancing is per connection. What you gain: Envoy never handles the keys
(compliance, client-certificate auth by the backend itself) and any
TLS-based protocol works (databases, MQTT over TLS, ...).

Notes:
- `tcp_proxy` also handles plain TCP (a filter chain without
  `filter_chain_match`), `weighted_clusters`, `idle_timeout` (1 h default),
  `max_connect_attempts`, and `access_log`.
- The backend sees Envoy's IP as the client. To pass the real client
  address, enable the PROXY protocol on the upstream connection
  (`proxy_protocol` transport socket) and in the backend.
- Envoy Gateway does this with a TLS listener in `mode: Passthrough` plus a
  TLSRoute (lesson 34); a TCPRoute is the plain-TCP version.
