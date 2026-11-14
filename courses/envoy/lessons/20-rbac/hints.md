The RBAC HTTP filter evaluates `policies`; with `action: ALLOW` a request
passes if any policy matches (both a permission and a principal), else
it gets 403 `RBAC: access denied`. Put it after `jwt_authn` and before
the router.

Permissions describe the request (`url_path`, `header` incl. `:method`,
`and_rules`, `or_rules`, `not_rule`, `any`), principals describe the caller
(`any`, `authenticated` (mTLS), `remote_ip`, `header`, `metadata`).
---
The caller's role is in the verified JWT. Make jwt_authn store the claims as
dynamic metadata with `payload_in_metadata: jwt_payload` on the provider,
then match it in a principal:

    principals:
    - metadata:
        filter: envoy.filters.http.jwt_authn
        path: [{key: jwt_payload}, {key: role}]
        value: {string_match: {exact: admin}}

Three policies: `public` (prefix /public/, any principal), `read-only`
(GET or HEAD and not /api/admin/, any verified token:
`value: {present_match: true}` on `sub`), `admin` (any permission, role admin).
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
