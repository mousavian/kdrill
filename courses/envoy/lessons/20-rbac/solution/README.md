# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

jwt_authn gets `payload_in_metadata: jwt_payload`, and after it:

    - name: envoy.filters.http.rbac
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC
        rules:
          action: ALLOW
          policies:
            public:
              permissions: [{url_path: {path: {prefix: "/public/"}}}]
              principals: [{any: true}]
            read-only:
              permissions:
              - and_rules:
                  rules:
                  - or_rules: {rules: [GET, HEAD as :method header matchers]}
                  - not_rule: {url_path: {path: {prefix: "/api/admin/"}}}
              principals:
              - metadata: {filter: envoy.filters.http.jwt_authn, path: [{key: jwt_payload}, {key: sub}], value: {present_match: true}}
            admin:
              permissions: [{any: true}]
              principals:
              - metadata: {filter: envoy.filters.http.jwt_authn, path: [{key: jwt_payload}, {key: role}], value: {string_match: {exact: admin}}}

How the two filters cooperate: jwt_authn verifies the token and writes its
claims into the request's **dynamic metadata** under
`envoy.filters.http.jwt_authn` / `jwt_payload`. RBAC reads them through
`metadata` principals. Nothing the client sends directly (like an `x-role`
header) is trusted. Filter order matters: RBAC before jwt_authn would see
no metadata.

Notes:
- `action: DENY` policies are the complement (block specific things, allow
  the rest); combine a DENY filter and an ALLOW filter for "deny these,
  then allow only those".
- `shadow_rules` evaluate a policy without enforcing it and record the
  result in stats (`rbac.shadow_allowed/denied`) and metadata: dry-run a
  new policy on real traffic first.
- Rules can also use CEL (`condition`) or the newer `matcher` tree.
- When decisions need data Envoy doesn't have (a database, OPA policies),
  the `ext_authz` filter asks an external service per request (HTTP or
  gRPC) and allows or denies based on its answer. Envoy Gateway exposes it
  as `SecurityPolicy.extAuth`; Istio's `AuthorizationPolicy` compiles to
  this same RBAC filter (and to ext_authz with `CUSTOM`).

Takeaways: authenticate first (jwt_authn, mTLS), then authorize on
verified attributes only; default-deny with ALLOW policies.
