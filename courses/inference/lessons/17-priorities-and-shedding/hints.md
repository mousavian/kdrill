    kubectl exec client -- ask -n 8 -c 4 -H 'x-gateway-inference-objective: batch' http://edge/v1/chat/completions
    kubectl explain inferenceobjective.spec
    kubectl logs deploy/epp | tail

The picker learns a request's importance from an InferenceObjective whose name is sent in the request header
`x-gateway-inference-objective`. Without a matching objective every request has priority 0.
---
Two objectives in the same namespace, apiVersion `llm-d.ai/v1`, kind InferenceObjective:

- `chat`: `spec.priority: 100`, `poolRefs: [{name: pool, group: inference.networking.k8s.io, kind: InferencePool}]`
- `batch`: `spec.priority: -10`, same poolRefs

Under saturation the picker drops requests with a negative priority with a 429 and keeps serving the others.
---
    kubectl apply -f solution/objectives.yaml      # from the lesson directory
