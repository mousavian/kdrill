# Authorization with the RBAC filter (and JWT claims)

## Concept

Authentication says who the caller is; **authorization** says what they may
do. Envoy's **`envoy.filters.http.rbac`** filter evaluates a set of
**policies** for each request:

- `action: ALLOW`: the request passes if at least one policy matches,
  otherwise 403 (`RBAC: access denied`). Default-deny. `action: DENY`
  inverts it (block what matches).
- A policy matches when **one of its permissions** and **one of its
  principals** match.
  - **Permissions** describe the request: `url_path`, `header` (including
    the pseudo-headers `:method`, `:path`, `:authority`), `destination_port`,
    and combinators `and_rules`, `or_rules`, `not_rule`, `any`.
  - **Principals** describe the caller: `any`, `authenticated` (the peer's
    mTLS certificate), `remote_ip` / `direct_remote_ip`, `header`, and
    `metadata`: values an earlier filter attached to the request.

The last one is how filters cooperate. `jwt_authn` (lesson 19) can write
the verified claims into the request's dynamic metadata
(`payload_in_metadata`), and RBAC can match `role == admin` there. A client
can't forge that, unlike a header.

`shadow_rules` evaluate a policy without enforcing it (results in the
`rbac.shadow_*` stats): roll out new rules in shadow mode first.

When the decision needs outside data (a user database, OPA/Rego policies,
a SaaS authorizer), the `ext_authz` filter calls an external HTTP or gRPC
service per request instead. Istio's AuthorizationPolicy compiles to this
same RBAC filter, so what you learn here carries over directly.

## The situation

Envoy already verifies JWTs on `/api/` (the solution of lesson 19, without
`payload_in_metadata`). Tokens in the ConfigMap `tokens`: `alice` (role
viewer), `bob` (role admin). Any valid token can do anything.

## Your task

- `/public/...`: anyone, no token needed;
- any valid token may `GET` or `HEAD` anything under `/api/` except
  `/api/admin/...`;
- only tokens whose `role` claim is `admin` may use other methods (POST,
  PUT, DELETE, ...) or access `/api/admin/...`; everything else is denied
  with 403 by the RBAC filter;
- the role is taken from the verified token, never from a header (verify
  sends alice's POST with `x-role: admin`);
- requests to `/api/` without a token still get 401.

## Useful commands

    ALICE=$(kubectl get cm tokens -o jsonpath='{.data.alice}'); BOB=$(kubectl get cm tokens -o jsonpath='{.data.bob}')
    kubectl exec client -- curl -si -X POST http://envoy:10000/api/orders -H "Authorization: Bearer $ALICE"
    kubectl exec client -- curl -si http://envoy:10000/api/admin/users -H "Authorization: Bearer $BOB"
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=rbac'

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/rbac_filter
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/rbac/v3/rbac.proto
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_filters/ext_authz_filter
