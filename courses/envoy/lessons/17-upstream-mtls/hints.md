What does Envoy get back today?

    kubectl exec client -- curl -si http://envoy:10000/pay/42
    kubectl logs deploy/payments

Envoy speaks plain HTTP to port 443. Upstream TLS is a `transport_socket`
on the **cluster** (the mirror image of the listener's), with an
`UpstreamTlsContext`.
---
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
            - {san_type: DNS, matcher: {exact: payments.lab.svc.cluster.local}}

Check the server certificate's names:
`kubectl get secret payments-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -A1 Alternative`
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
