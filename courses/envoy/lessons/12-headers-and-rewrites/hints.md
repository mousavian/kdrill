Look at what arrives today:

    kubectl exec client -- curl -s http://envoy:10000/api/v1/users -H 'x-env: prod' -H 'x-debug-token: s3cr3t'

Path rewrites and host rewrites are fields of the route action
(`prefix_rewrite`, `regex_rewrite`, `host_rewrite_literal`); header edits
can be set on a route, a virtual host or the whole route configuration
(`request_headers_to_add`, `request_headers_to_remove`,
`response_headers_to_add`, `response_headers_to_remove`).
---
    route:
      cluster: api
      prefix_rewrite: "/"
      host_rewrite_literal: api.internal
    request_headers_to_add:
    - header: {key: x-env, value: lab}
      append_action: OVERWRITE_IF_EXISTS_OR_ADD
    request_headers_to_remove: [x-debug-token]
    response_headers_to_add:
    - header: {key: x-served-by, value: envoy-lab}

The header lists sit next to `match` and `route`, not inside `route`.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
