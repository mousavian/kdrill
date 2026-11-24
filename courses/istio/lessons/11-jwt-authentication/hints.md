Two resources, both attached to the gateway with
`targetRefs: [{kind: Gateway, group: gateway.networking.k8s.io, name: shop-gateway}]`:

- `RequestAuthentication`: how to validate tokens (issuer, audiences, keys).
- `AuthorizationPolicy`: which requests need which token.

Decode a token to see its claims (they are just base64url JSON):

    cut -d. -f2 probes/tokens/alice.jwt | tr '_-' '/+' | base64 -d 2>/dev/null; echo
---
RequestAuthentication `jwtRules`: `issuer: https://auth.kdrill.local`,
`audiences: [shop]`, `jwks:` with the content of `manifests/jwks.json`
(as a string), and `outputClaimToHeaders: [{header: x-user, claim: sub}]`.

AuthorizationPolicy (ALLOW), three rules:
- `to` paths `/anything/public/*` (no `from`: anyone);
- `from` `requestPrincipals: [https://auth.kdrill.local/*]`, `to` `/anything/orders/*`;
- the same for `/anything/admin/*` plus
  `when: [{key: request.auth.claims[groups], values: [admins]}]`.
---
    kubectl apply -f solution/jwt.yaml
    kubectl -n outside exec deploy/visitor -c curl -- curl -s -H 'Host: shop.example.com' \
      -H "Authorization: Bearer $(cat probes/tokens/alice.jwt)" shop-gateway-istio.shop/anything/orders/1
