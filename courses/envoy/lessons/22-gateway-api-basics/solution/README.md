# Solution

From the lesson directory:

    kubectl apply -f solution/edge.yaml
    kubectl get gateway edge -w      # PROGRAMMED True after a few seconds

What was wrong:
- `gatewayClassName: envoy`: no such GatewayClass. Controllers only look at
  Gateways of classes they own, so nobody even wrote a status. The class
  installed by this course is `eg`.
- HTTPRoute `web` named a parent `gateway` that doesn't exist; its status
  said so (`Accepted: False`).
- `api.lab` had no route at all, so Envoy answered 404.

What Envoy Gateway did once the Gateway was accepted:
1. Created a Deployment and a Service `edge` in this namespace (this lab
   runs it in *GatewayNamespace* mode with a ClusterIP Service).
2. Translated Gateway + HTTPRoutes into Envoy config: one Envoy listener
   for the Gateway listener, a virtual host per hostname, a route per rule,
   a cluster per backendRef with the Service's pod IPs as EDS endpoints.
3. Streamed it to the Envoy pod over xDS (gRPC, port 18000 of the
   controller) and set `Programmed: True`.

Roles in the Gateway API:
- **GatewayClass** (cluster-scoped, infrastructure provider): which
  controller implements Gateways of this class, plus defaults
  (`parametersRef` to an EnvoyProxy).
- **Gateway** (cluster operator): where and how traffic enters: listeners
  with protocol, port, hostname, TLS, and which routes may attach.
- **HTTPRoute** (app teams): what to do with requests: match, filter, send
  to backends. Attaches to one or more Gateways (or listeners via
  `sectionName`).

Every object reports back in `status`: read it first when something
doesn't work.
