Try the table yourself and look at what Envoy runs:

    kubectl exec client -- hits -n 1 http://envoy:10000/v2/users -H 'Host: api.lab'
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=static_route_configs'

Two rules explain most surprises: within a virtual host the routes are
tried top to bottom and the first match wins; and `prefix` is a plain
string prefix (`/v2` matches `/v2beta`).
---
- Virtual host `web`: `domains: ["lab", "www.lab", "*.lab"]`. Exact domains
  beat wildcards across virtual hosts, so `api.lab` still goes to `api`.
- Virtual host `api`, in this order: a route with
  `headers: [{name: x-api-version, string_match: {exact: "2"}}]` -> api-v2;
  `path_separated_prefix: "/v2"` -> api-v2; `prefix: "/"` -> api-v1.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
