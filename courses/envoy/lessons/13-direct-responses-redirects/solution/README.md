# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

The virtual hosts, shortened:

    - name: new
      domains: ["new.lab"]
      routes:
      - match: {path: "/healthz"}
        direct_response: {status: 200, body: {inline_string: "ok\n"}}
      - match: {prefix: "/blog/"}
        redirect: {prefix_rewrite: "/news/", response_code: PERMANENT_REDIRECT}
      - match: {prefix: "/"}
        route: {cluster: web}
    - name: old
      domains: ["old.lab"]
      routes:
      - match: {path: "/healthz"}
        direct_response: ...
      - match: {prefix: "/"}
        redirect: {scheme_redirect: https, host_redirect: new.lab, response_code: MOVED_PERMANENTLY}
    - name: unknown
      domains: ["*"]
      routes:
      - match: {path: "/healthz"}
        direct_response: ...
      - match: {prefix: "/"}
        direct_response: {status: 404, body: {inline_string: "no such site\n"}}

Notes:
- Redirect codes: 301/302 let browsers turn a POST into a GET; 307/308
  keep the method and body. Use 308 for permanent API moves.
- `https_redirect: true` is the classic "HTTP listener sends everyone to
  HTTPS" (lesson 16 has an HTTPS listener); `strip_query` drops the query.
- `direct_response` bodies can come from a file (`filename`) and the HCM
  can rewrite error pages with `local_reply_config` (e.g. JSON errors for
  Envoy's own 404/503s).
- A catch-all virtual host is the place for "unknown site" handling; without
  one Envoy answers an empty 404.
- Health endpoints answered by the proxy itself say "the proxy is up", not
  "the app is up". Load balancers in front of Envoy often want exactly that
  (Envoy also has a `health_check` HTTP filter, which can include upstream
  health).

Takeaways: not every request needs a backend. Redirects, maintenance
pages, health endpoints and error pages are cheapest at the edge.
