# Envoy Gateway and the Gateway API: GatewayClass, Gateway, HTTPRoute

## Concept

In Part A you wrote Envoy config by hand. On Kubernetes you usually
describe *intent* with the **Gateway API** and let a controller generate
and stream the Envoy config. **Envoy Gateway** is the Envoy project's own
controller. The API splits responsibilities:

- **GatewayClass** (cluster-scoped): a kind of gateway and the controller
  that implements it (`controllerName`), like a StorageClass for traffic.
  This course installed one called `eg`.
- **Gateway**: an entry point with **listeners** (protocol, port, optional
  hostname and TLS) and rules for which routes may attach
  (`allowedRoutes`, default: routes in the same namespace). For every
  Gateway, Envoy Gateway runs an Envoy Deployment and a Service.
- **HTTPRoute**: matches requests (hostnames, paths, headers, ...) and sends
  them to `backendRefs` (Services). It attaches to a Gateway through
  `parentRefs`. Other route kinds: GRPCRoute, TLSRoute, TCPRoute, UDPRoute.

Controllers write their verdict into `status`: a Gateway is `Accepted` (the
class's controller took it) and `Programmed` (its data plane is configured
and has an address); each listener counts `attachedRoutes`; a route reports
per parent whether it was `Accepted` and whether its references resolved
(`ResolvedRefs`). A Gateway whose class has no controller gets no status at
all.

Envoy Gateway extends the API with its own policies
(`ClientTrafficPolicy`, `BackendTrafficPolicy`, `SecurityPolicy`,
`EnvoyProxy`, ...) that attach to Gateways and routes; later lessons use
them for what core Gateway API doesn't cover.

## The situation

Namespace `lab` has backends `web` and `api`, the client pod, a Gateway
`edge` and an HTTPRoute `web`, and no Envoy at all yet. In this lab Envoy
Gateway creates each Gateway's Envoy Deployment and ClusterIP Service in
the Gateway's own namespace, named like the Gateway, so the client reaches
this one at `http://edge`.

## Your task

- the Gateway `edge` is accepted and programmed, with its Envoy pod running;
- the HTTPRoute `web` attaches to `edge` and sends `Host: www.lab` to `web`;
- a new HTTPRoute `api` attaches to `edge` and sends `Host: api.lab` to `api`;
- both routes are accepted with resolved references (the listener shows 2
  attached routes), and other hosts get 404.

## Useful commands

    kubectl get gatewayclass,gateway,httproute
    kubectl describe gateway edge
    kubectl get httproute web -o jsonpath='{.status.parents[0].conditions}' | jq    # or -o yaml
    kubectl get pods,svc
    kubectl exec client -- hits http://edge/ -H 'Host: www.lab'
    kubectl -n envoy-gateway-system logs deploy/envoy-gateway --tail=20

When you think you're done: `kdrill verify`

## On a real cluster

Envoy Gateway normally runs every Envoy fleet in its own namespace
(`envoy-gateway-system`) and exposes Gateways through a Service of type
LoadBalancer, whose external IP becomes the Gateway's address. The lab has
no load balancer, so the component configures ClusterIP Services and the
GatewayNamespace deploy mode; Gateways still become Programmed, with the
ClusterIP as address.

## Read more

- https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/
- https://gateway.envoyproxy.io/v1.9/tasks/quickstart/
- https://gateway.envoyproxy.io/v1.9/tasks/operations/gateway-namespace-mode/
- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/
