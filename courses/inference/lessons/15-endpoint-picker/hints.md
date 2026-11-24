    kubectl get pods,svc,inferencepool          # the picker (epp) runs; the pool lists the pods it watches
    kubectl logs deploy/epp | tail -5
    kubectl exec client -- ask -n 40 -c 4 http://edge/v1/chat/completions    # who answers? (the saturated pod is labelled kdrill.dev/role=busy)

The gateway has to ask the picker about every request (ext_proc: a gRPC call that sees headers and
body), and then obey the answer. Two Envoy Gateway policies do that: an EnvoyExtensionPolicy for the call,
a BackendTrafficPolicy for the obeying (lesson 35 of the envoy course did the second one by hand).
---
1. EnvoyExtensionPolicy, target HTTPRoute `llm`: `extProc: [{backendRefs: [{name: epp, port: 9002}],
   messageTimeout: 5s, processingMode: {request: {body: FullDuplexStreamed}, response: {body: FullDuplexStreamed}}}]`.
2. BackendTrafficPolicy, target HTTPRoute `llm`:
   `loadBalancer: {type: LeastRequest, endpointOverride: {extractFrom: [{header: x-gateway-destination-endpoint}]}}`.
---
    kubectl apply -f solution/wiring.yaml      # from the lesson directory
