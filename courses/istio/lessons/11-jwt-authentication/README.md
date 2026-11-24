# End-user authentication: JWT at the ingress gateway

## Concept

mTLS identifies *workloads*. End users and API clients usually prove who
they are with a **JSON Web Token** (JWT) issued by an identity provider
(Keycloak, Auth0, Okta, Google, ...). A JWT is three base64url parts,
`header.payload.signature`; the payload holds **claims** such as `iss`
(issuer), `sub` (subject, the user), `aud` (audience), `exp` (expiry) and
custom ones like `groups`. The issuer signs it with its private key and
publishes the public keys as a **JWKS**.

Istio splits the job like it does for mTLS:

**RequestAuthentication**: how to validate tokens.

    apiVersion: security.istio.io/v1
    kind: RequestAuthentication
    spec:
      targetRefs:                     # or selector: for sidecars
      - {kind: Gateway, group: gateway.networking.k8s.io, name: shop-gateway}
      jwtRules:
      - issuer: https://auth.example.com
        audiences: [shop]
        jwksUri: https://auth.example.com/.well-known/jwks.json   # or jwks: inline
        outputClaimToHeaders:
        - {header: x-user, claim: sub}

A request **with an invalid token** (bad signature, expired, unknown
issuer, wrong audience) is rejected with **401**. A request **without a
token is accepted**, just without an identity. A valid token gives the
request a **request principal** `<iss>/<sub>`, e.g.
`https://auth.example.com/alice`, and makes its claims available.

**AuthorizationPolicy**: who may do what, now also by token:

    rules:
    - from:
      - source:
          requestPrincipals: ["https://auth.example.com/*"]   # any valid token
      to:
      - operation: {paths: [/orders/*]}
      when:
      - key: request.auth.claims[groups]
        values: [admins]

A request that is authenticated but not allowed gets **403**. So: 401 =
"your token is bad", 403 = "no token, or the token doesn't grant this".

Doing this at the **ingress gateway** checks every external request once,
at the edge; the services behind it get plain headers (here `X-User`).
`targetRefs` attaches a policy to a Gateway (or, in ambient mode, to a
Service or waypoint) instead of selecting Pods by label.

## The situation

Namespace `shop`: the backend `orders` (go-httpbin: `/anything/...` echoes
the request, including its headers) behind the Gateway `shop-gateway` and
HTTPRoute `shop` for `shop.example.com`. Namespace `outside`: the `visitor`
curl Pod. Anyone can call anything.

The identity provider `https://auth.kdrill.local` issues tokens with
audience `shop`. Its public keys are in `manifests/jwks.json`; sample
tokens are in `probes/tokens/` (`alice`: group customers, `root`: groups
customers and admins, `expired`, `forged` (wrong signing key),
`other-issuer`).

## Your task

On the gateway, in namespace `shop`:

- validate tokens from `https://auth.kdrill.local` for audience `shop`;
  invalid ones get 401;
- `/anything/public/*` is open to everyone, no token needed;
- `/anything/orders/*` needs a valid token (no token: 403);
- `/anything/admin/*` needs a valid token whose `groups` claim contains
  `admins`;
- the backend receives the token's `sub` in the header `x-user`.

## Useful commands

    T=$(cat probes/tokens/alice.jwt)
    kubectl -n outside exec deploy/visitor -c curl -- curl -s -w '\n%{http_code}\n' \
      -H 'Host: shop.example.com' -H "Authorization: Bearer $T" shop-gateway-istio.shop/anything/orders/1
    cut -d. -f2 probes/tokens/root.jwt | tr '_-' '/+' | base64 -d 2>/dev/null; echo
    kubectl -n shop get requestauthentication,authorizationpolicy
    kubectl -n shop logs deploy/shop-gateway-istio --tail=20

When you think you're done: `kdrill verify`

## On a real cluster

Use `jwksUri` so key rotation needs no config change (istiod fetches and
caches the keys), keep tokens short-lived, and decide whether the backend
also needs the original token (`forwardOriginalToken: true`). For login
flows with redirects (OIDC), put an external authorizer such as
oauth2-proxy behind `action: CUSTOM`.

## Read more

- https://istio.io/latest/docs/tasks/security/authentication/authn-policy/#end-user-authentication
- https://istio.io/latest/docs/reference/config/security/request_authentication/
- https://istio.io/latest/docs/reference/config/security/conditions/
- https://www.rfc-editor.org/rfc/rfc7519
