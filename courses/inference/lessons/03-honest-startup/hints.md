Watch what happens to a pod:

    kubectl get pods -w
    kubectl describe pod -l app=llm | grep -A3 -i probe
    kubectl exec client -- curl -s -o /dev/null -w '%{http_code}\n' http://<pod-ip>:8000/health
    kubectl exec client -- curl -s -o /dev/null -w '%{http_code}\n' http://<pod-ip>:8000/health/ready

The server answers `/health` (200) as soon as it runs but `/health/ready` only
returns 200 after the model is loaded (15 s here). Which probe should look at which?
---
- `startupProbe`: `httpGet /health/ready`, `periodSeconds: 2`, `failureThreshold: 30` (60 s budget).
- `livenessProbe`: `httpGet /health`, `periodSeconds: 10`.
- `readinessProbe`: `httpGet /health/ready`, `periodSeconds: 2`.

Liveness and readiness probes do not start until the startup probe has passed.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl get pods -w                      # ready after ~15-20 s, restarts 0
