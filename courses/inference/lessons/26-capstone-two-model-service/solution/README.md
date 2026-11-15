# Solution

From the lesson directory:

    kubectl apply -f solution/chat.yaml
    kubectl apply -f solution/routes.yaml
    kubectl apply -f solution/scaledobject.yaml
    kubectl apply -f solution/picker.yaml

The five faults, and where each is taught:

1. **Routing** (lesson 13): HTTPRoute `summarize` referenced a Service called `summarise` (typo): `ResolvedRefs=False`, so the route had
   no backend and summarize requests failed. Fixed to `summarize`. `kubectl describe httproute summarize` says so.
2. **Probes** (lesson 03): the liveness probe called `/health/ready`, which is 503 for the first 10 s while the model loads, so the kubelet killed
   every chat pod mid-load; readiness was a tcpSocket. Now `startupProbe` (/health/ready, 60 s budget), liveness on `/health`,
   readiness on `/health/ready`.
3. **Shutdown** (lesson 11): `terminationGracePeriodSeconds: 1` and no hook killed in-flight answers during a rollout. Now a `preStop` sleep of 8 s
   and a 30 s grace period.
4. **Autoscaling** (lesson 09): the ScaledObject read `running` (capped by the slots), allowed 3 replicas at most, polled every 30 s and waited 300 s
   to scale down. Now `inflight`, `targetValue: "3"` (slots per replica), max 5, polling 5 s, stabilization 15 s.
5. **Picker** (lesson 15): the endpoint picker was called through ext_proc (the Gateway's EnvoyExtensionPolicy `edge-filters`, which also carries the Lua filter: a target can have only one EnvoyExtensionPolicy, and a policy attached to the chat route would never run, because the route is chosen after the Lua filter) but Envoy ignored its answer: no
   `endpointOverride`. The BackendTrafficPolicy `chat-pick` makes Envoy forward to the chosen `ip:port`.

A systematic way through an unknown inference stack: follow one request. Gateway (is the route accepted, are references resolved?) ->
model routing (which backend did the header select?) -> picker (what did it answer, is it used?) -> pod (ready for real, or
restarting?) -> autoscaler (is it reading the right signal and allowed to act?) -> lifecycle (what happens when a pod goes away?).
