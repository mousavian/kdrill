# Outlier detection: eject the pod that keeps failing

## Concept

**Outlier detection** is passive health checking: instead of probing, Envoy
watches the responses of real requests and **ejects** hosts that behave
badly. An ejected host is removed from load balancing for
`base_ejection_time` multiplied by how often it has been ejected, then
returned; if it keeps failing, it's ejected again, for longer.

Detectors, configured per cluster in `outlier_detection`:

- `consecutive_5xx` (default 5): N 5xx responses (or connection failures)
  in a row from one host.
- `consecutive_gateway_failure`: N 502/503/504 or connection errors in a row.
- `success_rate_*`: hosts whose success rate is far below the cluster
  average (needs enough volume per `interval`).
- `failure_percentage_*`: hosts above an absolute failure percentage.

Guard rails: `max_ejection_percent` (default **10%**, but Envoy always
allows at least one ejection) and `enforcing_*` percentages to dry-run a
detector. `interval` (default 10 s) is how often the statistical
detectors run and ejections are reconsidered.

This matters in Kubernetes because readiness probes check the process,
not its answers. A pod with a broken database connection, a bad config or
a corrupted cache can pass readiness and still fail every request. Envoy
sees each response, so it can take that pod out within a few requests.

`/clusters` shows an ejected host with `health_flags::/failed_outlier_check`;
the stats are `cluster.<name>.outlier_detection.ejections_active`,
`ejections_enforced_total` and per detector.

## The situation

The headless Service `echo` selects three pods (label `pool=echo`): two
healthy echo pods and the pod `sick`, which passes readiness but answers
every request with 503 ("Name: broken"). The Envoy cluster `echo` sees all
three and round-robins, so a third of the requests fail.

## Your task

Configure the cluster `echo` in the ConfigMap `envoy` so that:

- `outlier_detection.consecutive_5xx` is 3 and `base_ejection_time` is at
  least 30 s;
- after 15 warm-up requests, the sick pod is ejected
  (`/failed_outlier_check`) and Envoy counted an enforced consecutive-5xx
  ejection;
- the next 30 requests all succeed, spread over both healthy pods.

Rules: keep the sick pod in the Service and the cluster (3 hosts), and
don't add active health checks or retries; this lesson is about passive
detection.

## Useful commands

    kubectl exec client -- hits -p -n 30 http://envoy:10000/
    kubectl exec client -- curl -s envoy:9901/clusters | grep -E 'health_flags|rq_error'
    kubectl exec client -- curl -s 'envoy:9901/stats?filter=outlier_detection'
    kubectl get pods -l pool=echo -o wide

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/outlier
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/cluster/v3/outlier_detection.proto
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/upstream/cluster_manager/cluster_stats#outlier-detection-statistics
