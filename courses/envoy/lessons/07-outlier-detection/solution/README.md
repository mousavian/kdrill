# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    outlier_detection:
      consecutive_5xx: 3
      interval: 5s
      base_ejection_time: 30s
      max_ejection_percent: 50

Envoy now counts consecutive 5xx (and connection failures, gateway errors)
per host. The third 503 in a row from the sick pod ejects it: it is removed
from load balancing for `base_ejection_time x number of times ejected` (30 s,
then 60 s, ...). After that it is put back; if it still fails, it is
ejected again for longer. `/clusters` shows `/failed_outlier_check` while
ejected, and `outlier_detection.ejections_*` stats count what happened.

Things to know:
- `max_ejection_percent` (default 10%) caps how much of a cluster can be
  ejected at once, so a bad deploy can't eject everything. Envoy always
  allows ejecting at least one host.
- Other detectors: `consecutive_gateway_failure` (502/503/504 only),
  `success_rate_*` (statistical, needs volume), `failure_percentage_*`,
  and local-origin errors (timeouts, resets) with
  `split_external_local_origin_errors`.
- Outlier detection is passive: it only learns from real requests, so a few
  users see the errors that trigger the ejection. Retries (lesson 09) hide
  those, and active health checks find hosts that are dead before any
  request arrives. In practice you combine them.
- Each Envoy decides on its own. With many Envoys each one has to see
  three failures before ejecting.

Takeaways: readiness says "the process is up"; outlier detection says "its
answers are bad". Use it on every cluster that has more than one host.
