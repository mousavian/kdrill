Reproduce the problem yourself with two terminals:

    kubectl exec client -- ask -n 36 -c 6 -t 20 -w 25 http://llm/v1/chat/completions
    kubectl rollout restart deploy/llm

Failures (status 000 or 5xx) in the first terminal are requests that were cut. Two things happen at pod
deletion, at the same time: the pod is removed from the Service endpoints (which takes a moment to reach
every node) and SIGTERM is sent; SIGKILL follows after the grace period. Each answer takes about 4.5 s.
---
- `lifecycle.preStop.sleep.seconds: 8` keeps the container serving while the endpoint removal
  spreads and in-flight requests finish (SIGTERM only follows the hook).
- `terminationGracePeriodSeconds: 30`: preStop (8 s) + drain + margin must fit in it.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl exec client -- ask -n 36 -c 6 -t 20 -w 25 http://llm/v1/chat/completions &   kubectl rollout restart deploy/llm
