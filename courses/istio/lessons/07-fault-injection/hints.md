Faults are part of an http route, next to `route:`. Scope them with a
`match` so only test traffic is hit:

    kubectl explain virtualservice.spec.http.fault
    kubectl explain virtualservice.spec.http.fault.abort
---
One route per behaviour, then the untouched catch-all last:

    - match: [{headers: {x-chaos: {exact: abort}}}]
      fault: {abort: {httpStatus: 503, percentage: {value: 100}}}
      route: [{destination: {host: ratings}}]
    - match: [{headers: {x-chaos: {exact: delay}}}]
      fault: {delay: {fixedDelay: 2s, percentage: {value: 100}}}
      route: [{destination: {host: ratings}}]

and the same for `flaky` with `httpStatus: 500` at 50%.
---
    kubectl apply -f solution/virtualservice.yaml
    kubectl -n shop exec deploy/web -c curl -- curl -s -H 'x-chaos: abort' ratings:8000/get
