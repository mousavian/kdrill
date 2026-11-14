Besides `route:`, a route can have one of two other actions:

- `direct_response: {status: 200, body: {inline_string: "ok\n"}}`
- `redirect: {...}` with `scheme_redirect`/`https_redirect`, `host_redirect`,
  `port_redirect`, `path_redirect` or `prefix_rewrite`, and
  `response_code` (`MOVED_PERMANENTLY` 301 is the default; `FOUND` 302,
  `SEE_OTHER` 303, `TEMPORARY_REDIRECT` 307, `PERMANENT_REDIRECT` 308).

    kubectl exec client -- curl -si http://envoy:10000/products/7 -H 'Host: old.lab'
---
- `/healthz` must work on every host, including unknown ones: add a route
  `match: {path: "/healthz"}` with the direct response to each virtual host,
  including a new catch-all virtual host `domains: ["*"]`.
- The catch-all's other route: `direct_response` with status 404 and body
  `no such site`.
- old.lab: one redirect route with `scheme_redirect: https` and
  `host_redirect: new.lab`. The path and query are kept automatically.
- new.lab: `/blog/` -> `redirect: {prefix_rewrite: "/news/", response_code: PERMANENT_REDIRECT}`,
  placed before the `/` route.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
