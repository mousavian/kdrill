# Ingress with the Gateway API: Gateway and HTTPRoute

## Concept

Sidecars handle traffic between workloads in the mesh. Traffic from
outside enters through an **ingress gateway**: a standalone Envoy at the
edge of the mesh that terminates client connections and routes them to
Services, applying the same Istio policies as a sidecar.

Istio supports two APIs to configure it:

- Istio's own `Gateway` + `VirtualService` (networking.istio.io). You
  install a gateway Deployment yourself and bind config to it by label.
- The **Kubernetes Gateway API** (gateway.networking.k8s.io): `GatewayClass`,
  `Gateway`, `HTTPRoute`. It is the Kubernetes standard, portable across
  implementations, and Istio's recommended API for new setups. With
  **automated deployment**, creating a `Gateway` of class `istio` makes
  istiod create a Deployment, Service and ServiceAccount named
  `<gateway-name>-istio` in the Gateway's namespace.

This course uses the **Gateway API for ingress** (and for waypoints in
lesson 13), and Istio's `VirtualService` / `DestinationRule` for traffic
inside the mesh (lessons 04-08), because that is where retries, fault
injection, subsets and outlier detection are richest and what most
existing meshes run. (HTTPRoute can also be attached to a Service for
mesh traffic, the GAMMA model, but this course does not use it.)

The pieces:

- **Gateway**: `gatewayClassName: istio` plus `listeners`, each with a port,
  protocol and optional `hostname`. Its status shows `Programmed` once
  Istio has an address for it.
- **HTTPRoute**: attaches to a Gateway (`parentRefs`), optionally limits
  `hostnames`, and has `rules`: `matches` (path, headers, query, method),
  `filters` (header changes, redirects, URL rewrites, mirroring) and
  `backendRefs` (Service + port, optionally weighted). The most specific
  match wins; order does not matter.
- Route status (`status.parents[].conditions`): `Accepted` (the Gateway
  took it) and `ResolvedRefs` (every backend exists).

## The situation

Namespace `shop` (in the mesh) runs `web` and `api`, both on Service port
8000. Namespace `outside` has no sidecars; its `visitor` Pod stands in for
a user on the internet. Nothing exposes the shop yet.

The lab cluster has no cloud load balancer, so annotate the Gateway with
`networking.istio.io/service-type: ClusterIP`; visitors reach it at
`shop-gateway-istio.shop.svc.cluster.local`.

## Your task

In namespace `shop`:

- a `Gateway` named `shop-gateway`, class `istio`, one HTTP listener on
  port 80 for host `shop.example.com`, Service type ClusterIP;
- an `HTTPRoute` named `shop` attached to it, for `shop.example.com`:
  - `/api/<path>` goes to `api` as `/<path>` (strip the prefix);
  - everything else goes to `web`;
- requests for any other host get a 404.

`kdrill verify` calls the gateway from `outside/visitor` with
`Host: shop.example.com` and checks which backend answered.

## Useful commands

    kubectl get gatewayclass
    kubectl -n shop get gateway,httproute
    kubectl -n shop describe gateway shop-gateway
    kubectl -n shop get deploy,svc shop-gateway-istio
    kubectl -n outside exec deploy/visitor -c curl -- curl -s -H 'Host: shop.example.com' shop-gateway-istio.shop/hostname
    istioctl proxy-config routes deploy/shop-gateway-istio -n shop

When you think you're done: `kdrill verify`

## On a real cluster

Keep the default `LoadBalancer` Service (or put the gateway behind your
cloud's load balancer), run at least two replicas with a
PodDisruptionBudget, and terminate TLS on an HTTPS listener with
`certificateRefs` pointing at a Secret (cert-manager can manage it).

## Read more

- https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/
- https://gateway-api.sigs.k8s.io/guides/http-routing/
- https://gateway-api.sigs.k8s.io/reference/spec/#httproute
- https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#automated-deployment
