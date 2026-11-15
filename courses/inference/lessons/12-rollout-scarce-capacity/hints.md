    kubectl rollout status deploy/llm --timeout=20s
    kubectl get rs
    kubectl describe rs -l app=llm | grep -i -B2 -A2 quota
    kubectl get resourcequota capacity

The Deployment wants to start one extra pod (maxSurge: 1) before it stops an old one, but the
namespace allows only 5 pods in total. With four model replicas and the client pod
there is no room. What if no extra pod is created and old ones are stopped first?
---
- `strategy.rollingUpdate: {maxSurge: 0, maxUnavailable: 1}`
- `minReadySeconds: 5` (a new pod must be ready that long before the next old pod is stopped)
- `kubectl create pdb llm --selector=app=llm --min-available=3`
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl apply -f solution/pdb.yaml
    kubectl rollout status deploy/llm --timeout=90s
