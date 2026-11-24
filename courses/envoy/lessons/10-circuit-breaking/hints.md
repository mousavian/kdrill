See the default limits and fire a burst:

    kubectl exec client -- curl -s envoy:9901/clusters | grep default_priority
    kubectl exec client -- hits -n 20 -c 20 -r x-envoy-overloaded 'http://envoy:10000/reports/q?wait=2s'

All 20 get through: the defaults are 1024 connections, 1024 pending, 1024
requests, 3 retries per cluster.
---
Circuit breakers are a cluster field:

    circuit_breakers:
      thresholds:
      - priority: DEFAULT
        max_connections: 4
        max_pending_requests: 2
        max_requests: 4

With HTTP/1.1 every in-flight request needs its own connection, so
`max_connections` limits concurrency and `max_pending_requests` is the
queue for a free connection.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
