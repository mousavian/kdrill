# Version routing: DestinationRule subsets and header matches

## Concept

A Kubernetes Service load-balances over every Pod its selector matches.
To run two versions behind one Service and decide per request which one
answers, Istio splits the job in two resources:

**DestinationRule** (what the destinations are, and how to talk to them):

    apiVersion: networking.istio.io/v1
    kind: DestinationRule
    spec:
      host: catalog            # the Service
      subsets:                 # named label selectors over its Pods
      - name: v1
        labels: {version: v1}
      trafficPolicy: ...       # load balancing, TLS, circuit breakers (lesson 08)

Each subset becomes its own Envoy cluster, e.g.
`outbound|8000|v1|catalog.shop.svc.cluster.local`.

**VirtualService** (who goes where):

    apiVersion: networking.istio.io/v1
    kind: VirtualService
    spec:
      hosts: [catalog]         # requests addressed to this host...
      http:                    # ...are matched against these routes, in order
      - match:
        - headers: {x-beta: {exact: "true"}}
          # also: uri {prefix|exact|regex}, method, queryParams, sourceLabels ...
        route:
        - destination: {host: catalog, subset: v2}
      - route:                 # no match = catch-all
        - destination: {host: catalog, subset: v1}

Routes are evaluated **top to bottom, first match wins**. Conditions inside
one `match` entry are ANDed; several `match` entries are ORed.

Routing happens on the **client side**: the VirtualService is turned into
route tables in the caller's sidecar (or gateway). A caller without a
sidecar bypasses it and gets plain Service load balancing.

If a route points at a subset whose labels select no Pod, Envoy has a
cluster with no endpoints and answers `503 no healthy upstream`.

## The situation

Namespace `shop` runs `catalog-v1` and `catalog-v2` (labels `app: catalog`
plus `version: v1` / `version: v2`) behind the Service `catalog`, and a
curl client `web`. Someone started a DestinationRule `catalog` but got a
subset wrong; there is no VirtualService.

## Your task

- Fix the DestinationRule `catalog` so subset `v1` selects `version: v1` and
  subset `v2` selects `version: v2`.
- Write a VirtualService `catalog` for host `catalog`:
  - requests with the header `x-beta: true` go to subset `v2`;
  - every other request (no header, or any other value) goes to `v1`.

`kdrill verify` sends requests from `web` to `catalog:8000/hostname`; each
backend answers with its Pod name.

## Useful commands

    kubectl -n shop exec deploy/web -c curl -- curl -s catalog:8000/hostname
    kubectl -n shop exec deploy/web -c curl -- curl -s -H 'x-beta: true' catalog:8000/hostname
    kubectl -n shop get destinationrule,virtualservice
    istioctl proxy-config clusters deploy/web -n shop --fqdn catalog.shop.svc.cluster.local
    istioctl proxy-config endpoints deploy/web -n shop --cluster 'outbound|8000|v2|catalog.shop.svc.cluster.local'
    istioctl analyze -n shop

When you think you're done: `kdrill verify`

## Read more

- https://istio.io/latest/docs/concepts/traffic-management/
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest
- https://istio.io/latest/docs/reference/config/networking/destination-rule/#Subset
- https://istio.io/latest/docs/tasks/traffic-management/request-routing/
