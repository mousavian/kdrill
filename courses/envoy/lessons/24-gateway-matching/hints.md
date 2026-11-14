A rule can have several `matches`; the rule applies if **any** of them
matches, and inside one match **all** conditions (path, method, headers,
queryParams) must hold:

    matches:
    - path: {type: PathPrefix, value: /v2}
    - headers: [{name: x-api-version, value: "2"}]

Unlike Envoy's own route list, the order of rules doesn't decide: the most
specific match wins (longest path, then method, then more headers, then
more query params).
---
- Route `web`: `hostnames: ["www.lab", "*.lab"]`.
- Route `api`, three rules:
  - default: `backendRefs: [{name: api-v1, port: 80}]`;
  - to api-v2, three alternative matches: `PathPrefix /v2`, header
    `x-api-version: "2"`, query param `canary: "true"`;
  - to orders: `{path: {type: Exact, value: /orders}, method: POST}`.
---
    kubectl apply -f solution/routes.yaml      # from the lesson directory
