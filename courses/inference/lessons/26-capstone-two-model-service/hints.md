Symptoms first, one component at a time:

    kubectl get pods                        # chat pods restarting? the summarize pods?
    kubectl get httproute                   # then: kubectl describe httproute summarize | tail
    kubectl get scaledobject,hpa,backendtrafficpolicy,envoyextensionpolicy
    kubectl exec client -- ask -m chat -n 4 http://edge/v1/chat/completions
    kubectl exec client -- ask -m summarize -n 4 http://edge/v1/chat/completions

The five faults map to lessons: 03 (probes), 09 (autoscaling signal and behaviour), 11 (shutdown), 13 (a route that
does not resolve), 15 (the picker is called but its answer is ignored).
---
- Routing: HTTPRoute `summarize` points at a Service that does not exist (`kubectl get svc`).
- Probes: the chat pods are killed by liveness on /health/ready during their 10 s load; readiness is a tcpSocket.
- Shutdown: `terminationGracePeriodSeconds: 1`, no preStop.
- Autoscaling: ScaledObject `chat`: `valueLocation: running`, max 3, polling 30, stabilization 300.
- Picker: a BackendTrafficPolicy with `loadBalancer.endpointOverride.extractFrom: [{header: x-gateway-destination-endpoint}]` on HTTPRoute `chat`.
---
    kubectl apply -f solution/chat.yaml        # from the lesson directory
    kubectl apply -f solution/routes.yaml
    kubectl apply -f solution/scaledobject.yaml
    kubectl apply -f solution/picker.yaml
