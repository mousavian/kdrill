Look at what the HPA sees, and what the model server says:

    kubectl get hpa llm
    kubectl top pods
    kubectl exec client -- curl -s http://aggregator/        # running / waiting summed over the replicas

CPU utilisation is usage divided by the CPU *request*. A simulator (like a real GPU server)
spends its time waiting, not computing: the HPA reads a few percent against a 50% target
and the queue grows. Who owns `spec.replicas` while an HPA exists?
---
1. `kubectl delete hpa llm` (otherwise the HPA scales your change back down).
2. `kubectl scale deploy/llm --replicas=4` (8 users, 2 slots per replica).
3. Wait for the pods to be ready and for `waiting` to fall to about 0.
---
    kubectl delete hpa llm
    kubectl scale deploy/llm --replicas=4
    kubectl rollout status deploy/llm --timeout=120s
