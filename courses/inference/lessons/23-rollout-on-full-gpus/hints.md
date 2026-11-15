    kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
    kubectl set env deploy/llm MODEL_VERSION=v9 && kubectl get pods -o wide -w

All 4 GPUs of `main-1` are used, so a surge pod has nowhere to go except `spare-1`, which is tainted.
Three changes to the Deployment (a taint needs a toleration, surge needs a number), and one new object.
---
- `strategy.rollingUpdate: {maxSurge: 1, maxUnavailable: 0}`
- `tolerations: [{key: capacity, operator: Equal, value: spare, effect: NoSchedule}]`
- PodDisruptionBudget `minAvailable: 4` on `app=llm`.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl apply -f solution/pdb.yaml
