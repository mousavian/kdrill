A route action can name one `cluster`, or a set of `weighted_clusters`:

    route:
      weighted_clusters:
        clusters:
        - {name: web-v1, weight: 90}
        - {name: web-v2, weight: 10}

Check the split with `kubectl exec client -- hits -n 200 http://envoy:10000/`.
---
For the opt-in, add a route *before* the weighted one that matches the
header and goes to `web-v2`:

    - match:
        prefix: "/"
        headers:
        - name: x-canary
          string_match: {exact: always}
      route: {cluster: web-v2}
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
