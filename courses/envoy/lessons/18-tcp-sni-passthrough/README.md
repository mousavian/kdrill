# TCP proxying and TLS passthrough by SNI

## Concept

Not everything Envoy proxies is HTTP. A filter chain can end in the
**`tcp_proxy`** network filter instead of the HTTP connection manager: it
connects to a cluster and copies bytes in both directions. That's L4
proxying: one upstream connection per downstream connection, load
balancing per connection, stats and access logs per connection.

**TLS passthrough** combines it with the `tls_inspector`: the listener
filter reads the server name (SNI) from the unencrypted ClientHello, a
filter chain is chosen by `server_names`, and its `tcp_proxy` forwards the
still-encrypted stream to the backend that owns that name. TLS is
negotiated end to end between client and backend; the proxy has no
certificate and can't see the requests.

Use it when the backend must terminate TLS itself: it authenticates
clients by certificate, the keys may not leave it, or the protocol inside
isn't HTTP (databases, MQTT, custom protocols over TLS). The price: none of
the HTTP features of the previous lessons (routing by path, retries, header
edits, per-request logs) apply.

Compare with lesson 16: there, SNI selected a chain with a
`DownstreamTlsContext` and an HCM, so Envoy decrypted the traffic. Here the
chain has no transport socket.

## The situation

`site-a` and `site-b` serve HTTPS themselves on port 443, with certificates
for `a.lab` and `b.lab` from the lab CA (the client pod trusts it at
`/certs/ca.crt`). Envoy's listener on 10443 forwards every connection to
site-a with a tcp_proxy.

## Your task

- TLS connections to Envoy port 10443 with SNI `a.lab` reach site-a, with
  SNI `b.lab` reach site-b; the client sees each backend's own certificate;
- other server names are refused;
- Envoy does not terminate TLS (no `DownstreamTlsContext`) and uses the TCP
  proxy, not the HTTP connection manager.

## Useful commands

    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to a.lab:10443:envoy:10443 https://a.lab:10443/
    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to b.lab:10443:envoy:10443 https://b.lab:10443/
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=^tcp\.'

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/listeners/network_filters/tcp_proxy_filter
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/listeners/tcp_proxy
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/listeners/listener_filters/tls_inspector
