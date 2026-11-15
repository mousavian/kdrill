Three steps, none needs a Pod restart:

    kubectl label namespace mall istio.io/dataplane-mode=ambient
    istioctl ztunnel-config workloads | grep mall     # PROTOCOL HBONE = enrolled

Then a waypoint: `istioctl waypoint apply -n mall --enroll-namespace`
(or write the Gateway yourself: `istioctl waypoint generate -n mall`).
---
The policy: an AuthorizationPolicy with
`targetRefs: [{kind: Service, group: "", name: api}]` (not a `selector`),
ALLOW, one rule: `from` principals `cluster.local/ns/mall/sa/web`, `to`
methods `[GET]`.

A `selector` policy is enforced by ztunnel, which cannot see HTTP methods.
---
    kubectl apply -f solution/ambient.yaml
    kubectl -n mall exec deploy/bot -c curl -- curl -s api:8000/get
    istioctl ztunnel-config workloads | grep mall
