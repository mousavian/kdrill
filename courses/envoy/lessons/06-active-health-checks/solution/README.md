# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    common_lb_config:
      healthy_panic_threshold: {value: 0}
    health_checks:
    - timeout: 1s
      interval: 1s
      no_traffic_interval: 1s
      unhealthy_threshold: 2
      healthy_threshold: 1
      http_health_check:
        path: /health

What was wrong:
- `/healthz` isn't a health endpoint of this app; like many apps, it serves
  something (here 200) for any unknown path, so the probe always passed.
  Probe an endpoint that really reflects the app's health.
- `interval: 10s` x `unhealthy_threshold: 5` = up to 50 s of traffic to a
  dead pod; recovery needed 3 x 10 s.
- `no_traffic_interval` (default **60 s**) replaces `interval` until the
  cluster has seen its first request. A freshly started Envoy probes idle
  clusters only once a minute, so a pod that breaks before traffic arrives
  goes unnoticed for up to a minute. verify tests exactly that, right after
  your restart.
- **Panic threshold**: when less than 50% (default) of a cluster's hosts are
  healthy, Envoy assumes the health checking is what's broken and balances
  over *all* hosts, healthy or not. That protects against a bad health
  endpoint taking the whole service down, but it also means "2 of 3 pods
  sick" sends 2/3 of the traffic to sick pods. Setting it to 0 disables
  panic mode; then, with no healthy host, requests fail fast with 503
  `no healthy upstream`.

Notes:
- Each Envoy probes each host itself: N Envoys x M hosts probes per interval.
  For large fleets, keep intervals sane or rely on Kubernetes readiness +
  EDS (Envoy Gateway does this) plus outlier detection (next lesson).
- `/clusters` shows `health_flags::/failed_active_hc`; stats
  `cluster.echo.health_check.failure`, `.healthy`, and gauges
  `membership_healthy`. `event_log_path` logs every transition.
- Kubernetes readiness also removes a pod from a headless Service's DNS, but
  only after kubelet probes fail and DNS/Envoy refresh; Envoy's own check
  sees a failure in about a second.

Takeaways: probe a real health endpoint, tune interval x thresholds for
your detection time, and know what the panic threshold does to you.
