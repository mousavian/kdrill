# Solution

    kubectl apply -f solution/virtualservice.yaml

Route `main` now has two weighted destinations (v1: 80, v2: 20) and a
`mirror` to subset v3 at 100%. In the client sidecar this becomes a route
with `weightedClusters` (`outbound|8000|v1|...` weight 80,
`outbound|8000|v2|...` weight 20) and a `requestMirrorPolicies` entry for
`outbound|8000|v3|...`.

Each request is weighted independently, so 200 requests give roughly
160/40, not exactly. v3's request log (`kubectl -n shop logs
deploy/catalog-v3 -c catalog`) shows every request; the copies arrive with
the host `catalog:8000-shadow`.

Next steps of a real canary: 50/50, then 0/100, then delete the v1
Deployment and the v1 subset. To roll back, set v1 back to 100; no
Deployment changes, no Pod restarts.

Takeaways:
- Weights split traffic per request, independent of replica counts.
- Mirroring tests a version with real traffic and no user impact, but only
  for requests without side effects.
