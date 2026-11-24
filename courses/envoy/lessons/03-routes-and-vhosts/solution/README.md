# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

The route configuration:

    virtual_hosts:
    - name: web
      domains: ["lab", "www.lab", "*.lab"]
      routes:
      - match: {prefix: "/"}
        route: {cluster: web}
    - name: api
      domains: ["api.lab"]
      routes:
      - match:
          prefix: "/"
          headers:
          - name: x-api-version
            string_match: {exact: "2"}
        route: {cluster: api-v2}
      - match: {path_separated_prefix: "/v2"}
        route: {cluster: api-v2}
      - match: {prefix: "/"}
        route: {cluster: api-v1}

Why it works:
- **Virtual host selection** looks at the Host header (`:authority`), in this
  order: exact domain, suffix wildcard (`*.lab`), prefix wildcard (`api.*`),
  then `*`. So `api.lab` picks `api` even though `*.lab` also matches it, and
  `example.com` matches nothing: 404.
- **Routes** are evaluated in order; the first whose `match` is true wins.
  The original `prefix: "/"` route came first and swallowed `/v2`.
- **Match types**: `prefix` (string prefix), `path` (exact),
  `path_separated_prefix` (prefix that ends at a `/` boundary), `safe_regex`
  (RE2, whole path), plus `headers`, `query_parameters`, and options like
  `case_sensitive`. All conditions of one `match` must hold.
- A header route that should win over path routes must come before them.

Takeaways: most-specific first; prefer `path_separated_prefix` for API
versions; check `config_dump` when routing surprises you.
