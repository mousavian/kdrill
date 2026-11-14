Today every connection goes to site-a, whatever name the client asks for:

    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to b.lab:10443:envoy:10443 https://b.lab:10443/

curl complains that the certificate doesn't match b.lab. The `tcp_proxy`
network filter forwards bytes; it doesn't know about TLS. To choose a
backend by name, Envoy must read the SNI from the ClientHello without
decrypting it.
---
- `listener_filters: [{name: envoy.filters.listener.tls_inspector, typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.listener.tls_inspector.v3.TlsInspector}}]`
- two filter chains, `filter_chain_match: {server_names: ["a.lab"]}` and
  `{server_names: ["b.lab"]}`, each with a `tcp_proxy` (`stat_prefix`,
  `cluster: site-a` / `site-b`);
- no `transport_socket` on them: Envoy must not terminate TLS.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
