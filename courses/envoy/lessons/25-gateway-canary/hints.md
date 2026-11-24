`backendRefs` takes several backends, each with an optional `weight`
(default 1). Traffic is split in proportion to the weights:

    backendRefs:
    - {name: web-v1, port: 80, weight: 90}
    - {name: web-v2, port: 80, weight: 10}
---
For the opt-in, add a second rule with
`matches: [{headers: [{name: x-canary, value: always}]}]` and only
`web-v2` as backend. A header match is more specific than no match, so it
wins regardless of rule order.
---
    kubectl apply -f solution/web.yaml      # from the lesson directory
