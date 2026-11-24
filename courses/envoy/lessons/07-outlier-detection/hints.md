See the damage and who causes it:

    kubectl exec client -- hits -p -n 30 http://envoy:10000/
    kubectl exec client -- curl -s envoy:9901/clusters | grep -E 'rq_error|rq_total|health_flags'

Readiness can't catch this pod: it is up, it just fails requests. Envoy
sees every response, so it can judge each host passively.
---
Add to the cluster:

    outlier_detection:
      consecutive_5xx: 3
      base_ejection_time: 30s
      max_ejection_percent: 50

`interval` (default 10 s) is when ejections are re-evaluated (and when
success-rate stats are computed); consecutive-5xx ejection itself happens
as soon as the third 5xx arrives.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
