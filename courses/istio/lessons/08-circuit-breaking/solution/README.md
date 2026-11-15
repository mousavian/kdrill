# Solution

    kubectl apply -f solution/destinationrule.yaml

**Outlier detection** (`consecutive5xxErrors: 2`, `baseEjectionTime: 2m`,
`maxEjectionPercent: 100`): the first two requests that land on the canary
fail; then `teller`'s sidecar ejects it and sends everything to the stable
Pod. `istioctl proxy-config endpoints deploy/teller -n bank --cluster
'outbound|8000||ledger.bank.svc.cluster.local'` shows the canary as
`UNHEALTHY` / `FAILED` in the OUTLIER CHECK column, and the stats counter
`outlier_detection.ejections_enforced_total` goes up. After 2 minutes the
canary is tried again and ejected again (for 4 minutes, then 6, ...).

**Circuit breaking** (`maxConnections: 1`, `http1MaxPendingRequests: 1`,
`maxRequestsPerConnection: 1`): of 10 concurrent requests, one gets the
single connection and at most one more may wait for it; the rest are
rejected at once with 503 and `x-envoy-overloaded: true`. In this lab
usually 9 of 10 are rejected. The stats counters `upstream_rq_pending_overflow`
and `upstream_cx_overflow` count them.

Takeaways:
- Outlier detection removes Pods that fail real traffic, even if their
  readiness probe passes.
- Circuit breakers fail fast with `503` + `x-envoy-overloaded` instead of
  queueing without limit.
- Both are per caller sidecar, configured in the DestinationRule.
