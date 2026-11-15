    kubectl get scaledobject,hpa
    kubectl describe scaledobject llm | tail -20
    kubectl exec client -- curl -s http://aggregator/

KEDA created an HPA (`keda-hpa-llm`) from the ScaledObject; the HPA computes
`replicas = ceil(metric / targetValue)` for an AverageValue-style metric. Which of the aggregator's
fields says how much work there is? `running` is capped by the number of slots; look at
`inflight`. Which settings slow the reaction: pollingInterval, the HPA's scaleDown window, maxReplicaCount?
---
- `maxReplicaCount: 5` (at least 4)
- `pollingInterval: 5`
- `triggers[0].metadata`: `valueLocation: inflight`, `targetValue: "2"` (slots per replica)
- `advanced.horizontalPodAutoscalerConfig.behavior.scaleDown.stabilizationWindowSeconds: 15`
---
    kubectl apply -f solution/scaledobject.yaml      # from the lesson directory
    kubectl get hpa -w
