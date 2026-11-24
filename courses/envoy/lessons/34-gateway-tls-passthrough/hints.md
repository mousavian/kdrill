Why isn't the TLSRoute accepted?

    kubectl get tlsroute site-a -o yaml | sed -n '/^status:/,$p'

A route kind can only attach to listeners whose protocol supports it: an
HTTP listener takes HTTPRoutes (and GRPCRoutes), a TLS listener takes
TLSRoutes, a TCP listener TCPRoutes.
---
Add a listener:

    - name: tls
      protocol: TLS
      port: 443
      tls: {mode: Passthrough}

and point both TLSRoutes at it (`parentRefs: [{name: edge, sectionName: tls}]`);
the second TLSRoute `site-b` has `hostnames: ["b.lab"]` and backend
`site-b` port 443.
---
    kubectl apply -f solution/edge.yaml      # from the lesson directory
