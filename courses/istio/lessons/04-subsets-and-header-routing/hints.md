Without any routing config the Service load-balances over all its Pods:

    kubectl -n shop exec deploy/web -c curl -- sh -c 'for i in 1 2 3 4 5 6; do curl -s catalog:8000/hostname; done'
    kubectl -n shop get pods --show-labels
    kubectl -n shop get destinationrule catalog -o yaml

Compare the subset labels with the Pod labels.
---
The DestinationRule defines *what* the subsets are (v2 must select
`version: v2`); a VirtualService for host `catalog` decides *who* goes
where. Two http routes, in this order:

1. `match: [{headers: {x-beta: {exact: "true"}}}]` -> `destination: {host: catalog, subset: v2}`
2. no match (catch-all) -> `destination: {host: catalog, subset: v1}`
---
    kubectl apply -f solution/destinationrule.yaml -f solution/virtualservice.yaml
    istioctl proxy-config routes deploy/web -n shop --name 8000 -o json | grep -A3 x-beta
