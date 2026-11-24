# Under the hood: from Gateway API objects to Envoy xDS

## Concept

Envoy Gateway is an xDS **management server** (lesson 21). It watches
Gateway API objects, its own policies, Services, EndpointSlices and
Secrets, translates them into Envoy resources, and streams them over gRPC
(ADS) to each Gateway's Envoy pods. The translation is predictable:

- each Gateway **listener** becomes an Envoy **listener** (LDS) and a
  **route configuration** (RDS); listeners sharing a port are merged;
- each **hostname** of an attached HTTPRoute becomes a **virtual host**;
- each route **rule** (and match) becomes an Envoy **route**, and its
  backendRefs a **cluster** (CDS) whose **endpoints** (EDS) are the pod IPs
  from the Service's EndpointSlices;
- filters and policies become HTTP filters, route options and cluster
  settings: the same fields you wrote by hand in Part A.

Debugging therefore has two layers:

1. **Status** on the objects: `Accepted`, `Programmed`, `ResolvedRefs`
   with a reason and message. Invalid references don't disappear quietly:
   the Gateway API requires a 500 for traffic to an invalid backend.
2. The **Envoy config** the controller actually produced: the admin
   interface of the Gateway's Envoy (127.0.0.1:19000 in the pod, reach it
   with `kubectl port-forward`), or Envoy Gateway's CLI `egctl`.

## The situation

The Gateway `edge` (listener `http`, port 80) is programmed. The HTTPRoute
`shop` for `shop.lab` sends `/cart` to `cart` (2 pods) and everything else
to `web`. `/cart` fails.

## Your task

1. Fix the HTTPRoute (not the Service) so `shop.lab/cart/...` reaches cart
   and the route is Accepted with ResolvedRefs.
2. Create a ConfigMap `answers` with these keys, read from the Gateway's
   Envoy (verify compares them with its admin interface):
   - `listener`: name of the Envoy listener for the Gateway's listener `http`;
   - `port`: the port that listener binds inside the pod;
   - `virtual_host`: name of the virtual host serving `shop.lab`;
   - `cart_cluster`: name of the cluster the `/cart` route sends to;
   - `cart_endpoints`: that cluster's endpoints as `ip:port`, space-separated.

## Useful commands

    kubectl get httproute shop -o yaml
    kubectl port-forward deploy/edge 19000 &        # then, on your machine:
    curl -s localhost:19000/listeners
    curl -s 'localhost:19000/config_dump?resource=dynamic_route_configs'
    curl -s localhost:19000/clusters | grep cx_active
    kubectl get endpointslices -l kubernetes.io/service-name=cart -o wide
    kubectl create configmap answers --from-literal=listener=... --from-literal=port=... ...

When you think you're done: `kdrill verify`

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/operations/egctl/
- https://gateway.envoyproxy.io/community/design/gatewayapi-translator/
- https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-docs/xds_protocol
