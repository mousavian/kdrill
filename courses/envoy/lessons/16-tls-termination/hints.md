TLS in Envoy is a **transport socket** on a filter chain. A listener can
have several filter chains, and `filter_chain_match.server_names` picks one
by the SNI the client sent (the `tls_inspector` listener filter reads it).

Test the way verify does:

    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to shop.lab:10443:envoy:10443 https://shop.lab:10443/
---
For each site, a filter chain:

    - filter_chain_match: {server_names: ["shop.lab"]}
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            alpn_protocols: [h2, http/1.1]
            tls_certificates:
            - certificate_chain: {filename: /certs/shop.crt}
              private_key: {filename: /certs/shop.key}
      filters: [ an HCM routing to cluster shop ]

On the HTTP listener, replace the routes with `redirect: {https_redirect: true}`.
Curl sends `Host: shop.lab:10443`, so list that domain too (or `*`).
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
