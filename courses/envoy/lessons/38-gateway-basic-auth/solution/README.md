# Solution

From the lesson directory:

    sh solution/create-secret.sh
    kubectl apply -f solution/securitypolicy.yaml

The Secret (`solution/create-secret.sh`) has one key, `.htpasswd`:

    ops:{SHA}<base64(sha1("kdrill-ops"))>

The policy:

    spec:
      targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: admin}]
      basicAuth:
        users: {name: admin-users}
        forwardUsernameHeader: x-user

- **401 vs 403**: 401 Unauthorized means "I don't know who you are"
  (missing or wrong credentials) and comes with a `WWW-Authenticate`
  challenge, which makes browsers show a login box. 403 Forbidden means "I
  know who you are, and you may not" (lesson 31, wrong audience or role).
- Envoy only checks `{SHA}` (SHA-1) htpasswd entries. That is weak hashing:
  basic auth at the edge is fine for internal tools behind TLS (lesson 29),
  not for customer logins. The password travels with every request, only
  base64-encoded.
- The policy targets the `admin` route only. Target the Gateway to protect
  everything on it; a policy on a route overrides one on its Gateway.
- If the Secret is missing or malformed, the policy is not Accepted and
  Envoy Gateway fails closed: requests on the route get an error instead of
  going through unauthenticated.
- `forwardUsernameHeader` lets the backend log or authorize by user without
  parsing credentials itself.
