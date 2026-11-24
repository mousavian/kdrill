Get a token and try it:

    TOKEN=$(kubectl get cm tokens -o jsonpath='{.data.alice}')
    kubectl exec client -- curl -si http://envoy:10000/api/orders -H "Authorization: Bearer $TOKEN"
    kubectl get cm tokens -o jsonpath='{.data.alice}' | cut -d. -f2 | base64 -d 2>/dev/null; echo

Today nothing is checked. JWT validation is the HTTP filter
`envoy.filters.http.jwt_authn`, placed before the router, with
`providers` (who issues tokens and how to verify them) and `rules`
(which requests need which provider).
---
    - name: envoy.filters.http.jwt_authn
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
        providers:
          lab:
            issuer: https://auth.lab
            audiences: [shop]
            local_jwks: {filename: /certs/jwks.json}
            claim_to_headers: [{header_name: x-user, claim_name: sub}]
        rules:
        - match: {prefix: "/api/"}
          requires: {provider_name: lab}
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
