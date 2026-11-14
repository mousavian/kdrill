Reproduce each failure and read what Envoy says:

    kubectl exec client -- curl -si http://envoy:10000/products/42 -H 'Host: shop.lab'
    kubectl exec client -- curl -si http://envoy:10000/products/42 -H 'Host: catalog.lab'
    kubectl exec client -- curl -si http://envoy:10000/products/42 -H 'Host: api.lab'

A 503 "upstream connect error" means Envoy could not connect to the host
it picked; "no healthy upstream" means the cluster had no usable host at
all; a 404 with an empty body and `server: envoy` means no route matched.
---
Now ask the admin interface:

    kubectl exec client -- curl -s envoy:9901/clusters | grep -E '::(cx_active|health_flags)'
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=connect_fail|membership_total|no_route'
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=static_clusters'

- shop: the host is `<ClusterIP>:8080`. `kubectl get svc shop` says 80.
- catalog: no host at all. Which DNS name does the cluster resolve?
- api: the route uses `path: "/"`, which is an exact match.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

Three fixes: shop port 8080 -> 80, catalog address `catalogue` -> `catalog`,
api route `path: "/"` -> `prefix: "/"`.
