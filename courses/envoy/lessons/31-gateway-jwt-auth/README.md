# SecurityPolicy: JWT authentication and claim-based authorization

## Concept

Envoy Gateway's **SecurityPolicy** bundles the access-control features of
lessons 19 and 20, attached to a Gateway or a route:

- **Authentication**: `jwt` (providers with issuer, audiences, keys from
  `remoteJWKS` or `localJWKS`, `claimToHeaders`), `oidc` (browser login),
  `basicAuth`, `apiKeyAuth`, and `extAuth` (delegate to an external
  service).
- **Authorization**: a `defaultAction` (Allow or Deny) and ordered `rules`,
  each with an `action`, an optional `operation` (methods, path) and a
  `principal`: verified JWT claims or scopes, client CIDRs (lesson 32),
  headers, even CEL expressions. The first rule that matches decides.

Under the hood these are the `jwt_authn` and RBAC filters you configured by
hand, with JWT claims passed to RBAC as metadata. Errors follow the same
pattern: **401** when authentication fails (no token, bad signature,
expired), **403** when the caller is known but not allowed (wrong
audience, no matching Allow rule).

A SecurityPolicy on a Gateway applies to all its routes; one on a route
overrides it (or merges, with `mergeType`), so a platform team can require
authentication everywhere while app teams refine authorization per route.

## The situation

Gateway `edge` and HTTPRoute `api` (`api.lab`) to the `shop` backend, open
to everyone. The issuer's JWKS is in the ConfigMap `jwks` (key `jwks`);
the test tokens are in the ConfigMap `tokens` (`alice` role viewer, `bob`
role admin, and `expired`, `forged`, `wrong-aud`), the same as in lesson 19.

## Your task

Create a SecurityPolicy on the HTTPRoute `api` (Accepted) so that:

- only valid tokens from `https://auth.lab` for audience `shop` get in: no
  token, expired or forged get 401, wrong audience 403;
- the backend receives `x-user` set from the `sub` claim (replacing any
  client-sent `x-user`);
- any valid token may `GET`/`HEAD`; other methods only with `role: admin`;
  everything else is denied (403).

## Useful commands

    ALICE=$(kubectl get cm tokens -o jsonpath='{.data.alice}'); BOB=$(kubectl get cm tokens -o jsonpath='{.data.bob}')
    kubectl exec client -- curl -si http://edge/api/orders -H 'Host: api.lab' -H "Authorization: Bearer $ALICE"
    kubectl exec client -- curl -si -X DELETE http://edge/api/orders/1 -H 'Host: api.lab' -H "Authorization: Bearer $BOB"
    kubectl get securitypolicy -o yaml
    kubectl explain securitypolicy.spec.authorization

When you think you're done: `kdrill verify`

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/security/jwt-authentication/
- https://gateway.envoyproxy.io/v1.9/tasks/security/jwt-claim-authorization/
- https://gateway.envoyproxy.io/v1.9/tasks/security/ext-auth/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#securitypolicy
