Make a pod sick yourself and watch Envoy:

    kubectl get pods -l app=echo -o wide
    kubectl exec client -- curl -s -X POST -d 500 http://<pod-ip>/health
    kubectl exec client -- curl -si http://<pod-ip>/health        # 500 now
    kubectl exec client -- curl -s envoy:9901/clusters | grep health_flags

Nothing changes. What does the health check request? Try
`curl -si http://<pod-ip>/healthz`: the echo app answers 200 on any
path, so that probe can never fail.
---
Health check fields: `http_health_check.path: /health`, `interval: 1s`,
`unhealthy_threshold: 2`, `healthy_threshold: 1`, `timeout: 1s`.

If it works only after you've sent some traffic: a cluster that never
had a request is probed every `no_traffic_interval` (default 60 s). Set it
to 1s too.

Then make two of three pods sick: traffic goes to all pods again. That is
the panic threshold (default 50%). Set
`common_lb_config: {healthy_panic_threshold: {value: 0}}` on the cluster.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
