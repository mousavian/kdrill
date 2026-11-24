See both problems first:

    kubectl -n bank exec deploy/teller -c curl -- sh -c 'for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code} " ledger:8000/get; done; echo'
    kubectl -n bank get pods -o wide

Both protections live in a DestinationRule for host `ledger`, under
`spec.trafficPolicy`: `outlierDetection` and `connectionPool`.
`kubectl explain destinationrule.spec.trafficPolicy`.
---
    trafficPolicy:
      outlierDetection:
        consecutive5xxErrors: 2
        interval: 5s
        baseEjectionTime: 2m
        maxEjectionPercent: 100
      connectionPool:
        tcp: {maxConnections: 1}
        http: {http1MaxPendingRequests: 1, maxRequestsPerConnection: 1}
---
    kubectl apply -f solution/destinationrule.yaml
    kubectl -n bank exec deploy/teller -c istio-proxy -- pilot-agent request GET stats | grep -e outlier -e overflow
