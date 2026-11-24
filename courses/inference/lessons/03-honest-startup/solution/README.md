# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

    startupProbe:   {httpGet: {path: /health/ready, port: http}, periodSeconds: 2, failureThreshold: 30}
    livenessProbe:  {httpGet: {path: /health, port: http}, periodSeconds: 10}
    readinessProbe: {httpGet: {path: /health/ready, port: http}, periodSeconds: 2}

What each probe is for:

- **startupProbe** gives the process time to load. Until it succeeds the kubelet runs
  neither liveness nor readiness, so a 15 s (or 5 min) load is never mistaken for a
  hang. Budget = `failureThreshold x periodSeconds` (60 s here); if the model is
  still not loaded then, the container is restarted.
- **livenessProbe** only answers "is the process stuck?". It must not depend on
  anything that is legitimately false for a while (loading, a long queue, GPU busy);
  that is what killed the pods in the starting state: `/health/ready` is 503 while loading.
- **readinessProbe** answers "should the Service send requests here?". A `tcpSocket`
  probe turns ready the moment the port opens, which for a real server can be long
  before the model is usable.
