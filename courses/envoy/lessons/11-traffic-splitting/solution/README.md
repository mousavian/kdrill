# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    routes:
    - match:
        prefix: "/"
        headers:
        - name: x-canary
          string_match: {exact: always}
      route: {cluster: web-v2}
    - match: {prefix: "/"}
      route:
        weighted_clusters:
          clusters:
          - {name: web-v1, weight: 90}
          - {name: web-v2, weight: 10}

Each request without the header picks a cluster at random by weight. It's
per request, not per user: one user's page loads can mix v1 and v2. If
that matters, make the choice sticky (hash a user header onto a
`header_name` in weighted clusters, or set a cookie on the first response
and route on it).

Ways to shift traffic:
- `weighted_clusters`: fixed weights in the config; change and reload
  (with xDS, the control plane pushes new weights; Argo Rollouts and
  Flagger do exactly that through Envoy Gateway or Istio).
- `runtime_fraction` on a route match: a percentage that can be changed at
  runtime (admin `/runtime_modify`), without a config push.
- `request_mirror_policies`: copy (shadow) a share of requests to v2 and
  throw the answers away, to test v2 with real traffic at no user risk.

Takeaways: canary = weights for everyone plus an explicit opt-in for
testers, with metrics per cluster (`cluster.web-v2.upstream_rq_5xx`) to
decide whether to go on.
