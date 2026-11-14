# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

The new listener `https` on 10443:

- `listener_filters: [envoy.filters.listener.tls_inspector]` peeks at the
  TLS ClientHello and records SNI and ALPN before a filter chain is chosen.
- Two filter chains with `filter_chain_match.server_names` `shop.lab` and
  `api.lab`. Each has a `DownstreamTlsContext` with its own certificate and
  `alpn_protocols: [h2, http/1.1]`, and its own HCM and routes.
- No chain without a match, so other SNI values (or none) are refused.

The plain listener now only answers `redirect: {https_redirect: true}`
(301 to `https://<host><path>`, port 443).

Notes:
- The certificate files come from the Secret `envoy-certs`, mounted at
  `/certs`. Envoy watches files referenced this way and reloads them when
  they change, so a rotated Secret is picked up without a restart. With
  xDS, certificates usually come over SDS (secret discovery), which is how
  Envoy Gateway and Istio deliver them.
- One filter chain can hold several certificates (e.g. RSA + ECDSA), and
  one filter chain can serve many names; separate chains are needed when
  the TLS settings or the routes differ.
- `tls_params` sets protocol versions and ciphers (Envoy's default minimum
  is TLS 1.2); `require_client_certificate` + `validation_context` turns
  this into mTLS for clients.
- Because curl connects to `shop.lab:10443`, the Host header carries the
  port; the virtual hosts list both forms.

Takeaways: SNI picks the filter chain (certificate, TLS settings and
HCM); the Host header then picks the virtual host inside it.
