# JWT authentication at the proxy

## Concept

Most APIs authenticate callers with **JSON Web Tokens** issued by an
identity provider (Keycloak, Auth0, Okta, Entra ID, Kubernetes service
account tokens, ...). A JWT is three base64url parts: a header (algorithm,
key id `kid`), claims (`iss` issuer, `aud` audience, `sub` subject,
`exp` expiry, custom claims like `role`), and a signature over both.

Envoy's **`envoy.filters.http.jwt_authn`** HTTP filter validates tokens
before the request reaches any backend:

- `providers`: each has an `issuer`, accepted `audiences`, and where the
  public keys come from: `remote_jwks` (the provider's JWKS URL, cached) or
  `local_jwks` (inline or file). Plus where to find the token (default
  `Authorization: Bearer`), whether to `forward` it upstream, and
  `claim_to_headers` / `payload_in_metadata` to pass claims on.
- `rules`: route-like matches deciding which requests need which provider
  (`requires: {provider_name: ...}`, `requires_any`, `requires_all`,
  `allow_missing`). A rule without `requires` means no check.

A failed check is answered by Envoy: **401** when the token is missing,
expired or doesn't verify; **403** when it's valid but not for this
audience. Stats are under `http.<stat_prefix>.jwt_authn.*`.

Validating at the edge means backends don't each need JWT libraries and
key rotation logic; they get a trusted identity header instead. That trust
only holds if the proxy overwrites the header and nothing reaches the
backend around the proxy, which is where mTLS and network policy (and a
mesh) come in.

## The situation

The `shop` backend serves `/public/...` and `/api/...` through Envoy, with
no authentication. Test tokens from the issuer `https://auth.lab` are in
the ConfigMap `tokens`: `alice` (role viewer) and `bob` (role admin) are
valid for audience `shop`; `expired`, `wrong-aud` (audience `billing`)
and `forged` (signed with another key) are not. The issuer's public keys
are mounted into Envoy at `/certs/jwks.json`.

## Your task

- `/public/...` works without a token;
- `/api/...` requires a valid token from `https://auth.lab` for audience
  `shop`: no token, an expired or a forged token get 401; a token for
  another audience gets 403; alice's token gets 200;
- the backend receives the caller's `sub` claim in `x-user` (replacing any
  client-sent `x-user`) and does not receive the token itself.

## Useful commands

    kubectl get cm tokens -o yaml
    TOKEN=$(kubectl get cm tokens -o jsonpath='{.data.alice}')
    kubectl exec client -- curl -si http://envoy:10000/api/orders -H "Authorization: Bearer $TOKEN"
    kubectl get cm tokens -o jsonpath='{.data.wrong-aud}' | cut -d. -f2 | base64 -d 2>/dev/null; echo
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=jwt_authn'

When you think you're done: `kdrill verify`

## On a real cluster

The lab's tokens were signed once, the private key discarded, and they
"expire" in 2100. A real issuer rotates its signing keys; use
`remote_jwks` with caching so Envoy picks up new keys, and keep token
lifetimes short.

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/jwt_authn_filter
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/extensions/filters/http/jwt_authn/v3/config.proto
- https://datatracker.ietf.org/doc/html/rfc7519
