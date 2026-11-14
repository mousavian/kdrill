Time it:

    kubectl exec client -- curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' 'http://envoy:10000/api/items?wait=3s'
    kubectl exec client -- curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' 'http://envoy:10000/api/items?wait=20s'

The second one ends after 15 s with 504: that's the default route timeout.
---
`timeout` is a field of the route action, next to `cluster`:

    route:
      cluster: api
      timeout: 1s

and `timeout: 10s` for `/reports/`.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
