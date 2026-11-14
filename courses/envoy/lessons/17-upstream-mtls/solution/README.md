# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: payments.lab.svc.cluster.local
        common_tls_context:
          tls_certificates:
          - certificate_chain: {filename: /certs/client.crt}
            private_key: {filename: /certs/client.key}
          validation_context:
            trusted_ca: {filename: /certs/ca.crt}
            match_typed_subject_alt_names:
            - san_type: DNS
              matcher: {exact: payments.lab.svc.cluster.local}

The three parts of an mTLS client:
- **Identity**: `tls_certificates` is the certificate Envoy presents when the
  server asks for one. The echo app prints its subject
  (`Certificate[0] Subject: CN=envoy-client`).
- **Trust**: `trusted_ca` + `match_typed_subject_alt_names`. Without a
  `validation_context`, Envoy encrypts but accepts any certificate, so
  anyone who can intercept the connection can impersonate the backend.
  Checking the CA without the name lets any service with a cert from the
  same CA impersonate this one.
- **SNI**: `sni` tells the server which name you want (needed by servers
  with several certificates, and by TLS passthrough proxies, next lesson).
  `auto_sni: true` in the cluster's `upstream_http_protocol_options`
  derives it from the Host header instead.

Where this goes next: in a service mesh every connection is mTLS like
this one, with short-lived certificates delivered over SDS and identities
as SPIFFE URIs (`spiffe://cluster.local/ns/lab/sa/payments`) matched with
`san_type: URI`. Istio does exactly this with the same Envoy fields, and
Envoy Gateway's BackendTLSPolicy (Gateway API) and EnvoyProxy client
certificates produce this config too.
