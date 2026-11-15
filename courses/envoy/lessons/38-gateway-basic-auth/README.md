# SecurityPolicy: basic auth for one route

## Concept

Checking who a client is at the Gateway keeps every backend from having to
do it. Lesson 31 used JWTs; the simplest alternative in a **SecurityPolicy**
is `basicAuth`:

| Field | Checks |
|---|---|
| `basicAuth` | user + password against an htpasswd Secret |
| `apiKeyAuth` | API keys in a header, query parameter or cookie |
| `jwt` | signed tokens from an identity provider (lesson 31) |
| `oidc` | browser login flow with an OpenID Connect provider |
| `extAuth` | ask your own HTTP/gRPC auth service |

The client sends `Authorization: Basic base64(user:password)`; Envoy
compares it with a Secret that has one key, `.htpasswd`, holding lines like
`user:{SHA}<base64 of the SHA-1 of the password>`. No or wrong credentials:
**401** with a `WWW-Authenticate: Basic` challenge.

    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: SecurityPolicy
    metadata: {name: protect-reports}
    spec:
      targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: reports}]
      basicAuth:
        users: {name: reports-users}       # Secret with key .htpasswd

## The situation

Gateway `edge` (HTTP :80) and two HTTPRoutes for `shop.lab`: `admin`
(`/admin` to Service `admin`) and `web` (everything else to `web`). Anyone
can open the admin pages.

## Your task

- Create a Secret `admin-users` with the user `ops`, password `kdrill-ops`,
  in htpasswd `{SHA}` format.
- Protect the `admin` route with basic auth from that Secret (and an
  Accepted SecurityPolicy): no or wrong credentials get 401, `ops` /
  `kdrill-ops` gets through.
- The admin backend receives the logged-in user's name in the request
  header `x-user`.
- The `web` route stays open.

## Useful commands

    kubectl explain securitypolicy.spec.basicAuth
    kubectl get securitypolicy
    kubectl describe securitypolicy
    printf '%s' 'kdrill-ops' | openssl dgst -binary -sha1 | openssl base64
    kubectl exec client -- curl -si -H 'Host: shop.lab' http://edge/admin/panel
    kubectl exec client -- curl -s -u ops:kdrill-ops -H 'Host: shop.lab' http://edge/admin/panel

When you think you're done: `kdrill verify`

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/security/basic-auth/
- https://gateway.envoyproxy.io/v1.9/concepts/gateway_api_extensions/security-policy/
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication
