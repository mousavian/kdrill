A route can list several destinations, each with a `weight`; Envoy picks
one per request according to the weights:

    kubectl -n shop get virtualservice catalog -o yaml
    kubectl explain virtualservice.spec.http.route.weight
    kubectl explain virtualservice.spec.http.mirror
---
In route `main`:

    route:
    - destination: {host: catalog, subset: v1}
      weight: 80
    - destination: {host: catalog, subset: v2}
      weight: 20
    mirror: {host: catalog, subset: v3}
    mirrorPercentage: {value: 100.0}

`mirror` sits next to `route`, not inside it.
---
    kubectl apply -f solution/virtualservice.yaml
    kubectl -n shop logs deploy/catalog-v3 -c catalog --tail=5   # mirrored requests
