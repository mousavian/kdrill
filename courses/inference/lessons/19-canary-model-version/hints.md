    kubectl exec client -- ask -n 30 -c 3 http://edge/v1/chat/completions     # all v2- pods today
    kubectl explain httproute.spec.rules.backendRefs.weight

Weights are relative within one rule: 90 and 10 give 90%/10%. A rule that matches a header must come
before the general rule, because the first matching rule wins (most specific match wins in Gateway API;
here write the header rule explicitly).
---
    rules:
    - matches: [{headers: [{name: x-canary, value: always}]}]
      backendRefs: [{name: v2, port: 80}]
    - backendRefs:
      - {name: v1, port: 80, weight: 90}
      - {name: v2, port: 80, weight: 10}
---
    kubectl apply -f solution/route.yaml      # from the lesson directory
