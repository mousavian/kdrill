# Solution

    kubectl apply -f solution/jwt.yaml

- `RequestAuthentication jwt` (target: the Gateway): issuer
  `https://auth.kdrill.local`, audience `shop`, the JWKS inline, and
  `outputClaimToHeaders` copying `sub` into `x-user`. The gateway's Envoy
  gets a `jwt_authn` filter that verifies signature, `exp`, `iss` and `aud`.
- `AuthorizationPolicy require-jwt` (target: the Gateway, ALLOW) with three
  rules: public paths for anyone; orders for any request principal of the
  issuer; admin for request principals whose `groups` claim contains
  `admins`.

| Request | Authentication | Authorization | Result |
|---|---|---|---|
| public, no token | passes (no identity) | rule 1 | 200 |
| orders, no token | passes (no identity) | no rule | 403 |
| orders, alice | valid | rule 2 | 200, backend sees `X-User: alice` |
| orders, expired / forged / other issuer | **fails** | - | 401 |
| admin, alice (customers) | valid | rule 3 `when` fails | 403 |
| admin, root (admins) | valid | rule 3 | 200 |

The backend never sees the `Authorization` header: Istio removes the token
after validating it unless `forwardOriginalToken: true`.

Takeaways:
- RequestAuthentication rejects bad tokens but lets missing tokens through;
  the AuthorizationPolicy makes them mandatory.
- 401 = invalid token, 403 = not allowed.
- Validate once at the edge, pass identity to services as headers.
