# Solution

From the lesson directory:

    kubectl apply -f solution/web.yaml

    rules:
    - backendRefs:
      - {name: web-v1, port: 80, weight: 90}
      - {name: web-v2, port: 80, weight: 10}
    - matches:
      - headers: [{name: x-canary, value: always}]
      backendRefs:
      - {name: web-v2, port: 80}

Envoy Gateway turns the weighted rule into an Envoy route with
`weighted_clusters` (lesson 11): look for it in
`config_dump?resource=dynamic_route_configs` (port-forward to
`deploy/edge`). The header rule becomes a route with a header matcher,
sorted before it.

Rolling forward is now a one-line change (`weight: 50`, then `100`/`0`),
applied in about a second without restarting anything: Envoy Gateway
pushes new weights over xDS. Progressive delivery tools (Argo Rollouts'
Gateway API plugin, Flagger) automate exactly that: change weights, watch
metrics, roll back on errors.

Notes:
- `weight: 0` keeps a backend referenced but unused.
- A backendRef that can't be resolved receives its share as 500s, so a typo
  in a canary Service name fails 10% of requests, visibly.
- Splitting is per request. For per-user stickiness use a header/cookie
  match, or session persistence (`sessionPersistence` on the rule).
