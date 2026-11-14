# Solution

From the lesson directory:

    kubectl apply -f solution/security.yaml

The SecurityPolicy `api-auth` on the HTTPRoute `api` has two parts:

- `jwt.providers`: issuer, audiences, keys from the ConfigMap (`localJWKS`
  `ValueRef`), and `claimToHeaders` for `x-user`. Envoy Gateway renders
  the `jwt_authn` filter of lesson 19, with the token removed before it
  reaches the backend.
- `authorization`: `defaultAction: Deny` and two Allow rules matched on
  verified JWT claims (and methods). Envoy Gateway renders the RBAC filter
  of lesson 20, with `metadata` principals reading the claims.

Results: missing/expired/forged token 401 (authentication), wrong
audience 403, a valid token without the right claim for the method 403
(`RBAC: access denied`).

Other SecurityPolicy features, same pattern:
- `basicAuth` (htpasswd Secret), `apiKeyAuth` (keys in a Secret, sent in a
  header or query param);
- `oidc`: full browser login flow (redirect to the IdP, cookies);
- `extAuth`: call an HTTP or gRPC authorization service per request (OPA,
  oauth2-proxy, your own), Envoy's `ext_authz` filter;
- `cors`, `csrf`, and authorization by `clientCIDRs` (next lesson) or
  headers.

Production: point `remoteJWKS` at your IdP's JWKS URL instead of a
ConfigMap, and keep authorization on verified claims only.
