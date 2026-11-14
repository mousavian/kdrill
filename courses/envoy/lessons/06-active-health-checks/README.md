# Active health checking (and the panic threshold)

## Concept

**Active health checking**: Envoy itself probes every host of a cluster on a
timer and takes hosts that fail out of load balancing. Configured per
cluster in `health_checks`:

- the probe: `http_health_check` (path, expected statuses, host header),
  `tcp_health_check` (connect, optional payload) or `grpc_health_check`;
- `interval` (and `interval_jitter`), `timeout`;
- `unhealthy_threshold`: consecutive failures before a host is marked
  unhealthy; `healthy_threshold`: consecutive successes to bring it back.
  Detection time is roughly `interval x unhealthy_threshold`.
- `no_traffic_interval`: used instead of `interval` while the cluster has
  never received a request. The default is 60 s.

`/clusters` shows each host's `health_flags`: `healthy`, or
`/failed_active_hc` when the probe marked it down (also
`/failed_outlier_check` from the next lesson, `/pending_dynamic_removal`, ...).

The **panic threshold** surprises people. If the share of healthy hosts in
a cluster drops below `healthy_panic_threshold` (default **50%**), Envoy
concludes that health checking itself is unreliable and load-balances
across **all** hosts, ignoring health. It's a safety net against a broken
health endpoint draining a whole service, but in a real incident ("2 of 3
pods are sick") it sends most traffic to sick pods. Set it per cluster
with `common_lb_config.healthy_panic_threshold`; `0` disables panic mode.
The stat `cluster.<name>.lb_healthy_panic` counts panicked picks.

In Kubernetes, readiness probes already remove pods from Services. Active
health checks are still useful because they are Envoy's own view and are
fast. With hundreds of Envoys, keep in mind every Envoy probes every host.

## The situation

`echo` runs 3 pods behind a headless Service, and the cluster `echo` has a
health check that never fails. The echo app's real health endpoint is
`/health`: it answers 200 until someone POSTs another status code to it
(`curl -X POST -d 500 http://<pod-ip>/health`); any other path, including
`/healthz`, is answered with 200 and the normal echo page.

## Your task

Fix the cluster `echo` in the ConfigMap `envoy` so that (verify flips pods'
`/health` and watches):

- a pod whose `/health` returns 500 is marked `/failed_active_hc` within 8 s
  and gets no traffic, even when it breaks right after Envoy started and
  before any request went through (verify checks this first);
- when 2 of the 3 pods are unhealthy, all traffic goes to the one healthy
  pod (no panic routing);
- pods that recover are healthy again within 8 s and get traffic again;
- the cluster keeps the 3 echo pods as hosts.

## Useful commands

    kubectl get pods -l app=echo -o wide
    kubectl exec client -- curl -s -X POST -d 500 http://<pod-ip>/health
    kubectl exec client -- curl -s envoy:9901/clusters | grep health_flags
    kubectl exec client -- hits -p -n 30 http://envoy:10000/
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=echo.(health_check|lb_healthy_panic|membership)'

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/health_checking
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/load_balancing/panic_threshold
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/core/v3/health_check.proto
