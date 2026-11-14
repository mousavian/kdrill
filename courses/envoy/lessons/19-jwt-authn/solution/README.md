# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    - name: envoy.filters.http.jwt_authn
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
        providers:
          lab:
            issuer: https://auth.lab
            audiences: [shop]
            local_jwks: {filename: /certs/jwks.json}
            claim_to_headers:
            - {header_name: x-user, claim_name: sub}
        rules:
        - match: {prefix: "/public/"}
        - match: {prefix: "/api/"}
          requires: {provider_name: lab}

What Envoy checks for `/api/`: a token is present (`Authorization: Bearer`
by default), its signature verifies with a key from the JWKS (matched by
`kid`), `iss` equals the issuer, `aud` contains `shop`, and `exp`/`nbf`
are valid (60 s clock skew allowed). Missing, expired or badly signed: 401.
A valid token for the wrong audience: 403 (authenticated, but not for
this service).

Notes:
- `remote_jwks` (an HTTPS URL plus a cluster for it, cached and refreshed)
  is what you use with a real identity provider; `local_jwks` suits
  tests and air-gapped setups.
- `forward: false` (the default) strips the token before proxying; set it to
  true only if the backend needs the token itself.
  `forward_payload_header` passes the verified claims base64-encoded.
- `claim_to_headers` *replaces* any client-sent value of the header, so the
  backend can trust `x-user`, as long as every path to the backend goes
  through Envoy.
- `requires` can combine providers: `requires_any`, `requires_all`, and
  `allow_missing` (validate if present, let anonymous through) for mixed
  pages.
- `payload_in_metadata` stores the claims as dynamic metadata for later
  filters, which is how the next lesson authorizes by role.

Takeaways: validate tokens once at the edge, hand the backend a trusted
identity header, and keep authentication (who) separate from authorization
(what they may do, next lesson).
