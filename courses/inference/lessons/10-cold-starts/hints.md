    kubectl get scaledobject,deploy
    kubectl describe pod -l app=llm | grep -A12 Events:       # once a pod exists
    kubectl get pod -l app=llm -o jsonpath='{.items[0].metadata.creationTimestamp} {.items[0].status.conditions}'

Three things add seconds to every start: how often the startup probe looks (10 s), whether the
kubelet checks the registry even though the node already has the image, and having no replica
at all when the request arrives.
---
- ScaledObject: `minReplicaCount: 1`
- Deployment: container `imagePullPolicy: IfNotPresent`, `startupProbe.periodSeconds: 2`
  (raise `failureThreshold` to 30 to keep the 60 s budget)
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl get pods -w                      # ready ~22 s after creation
