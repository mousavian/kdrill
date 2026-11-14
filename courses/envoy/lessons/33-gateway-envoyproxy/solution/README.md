# Solution

From the lesson directory:

    kubectl apply -f solution/edge.yaml

It creates the EnvoyProxy `edge-proxy` (`mergeType: StrategicMerge`, pod
label, resource requests, JSON access log to stdout) and points the
Gateway's `spec.infrastructure.parametersRef` at it. Envoy Gateway rolls
the `edge` Deployment (new pod template) and pushes the new access log
config over xDS.

The trap: EnvoyProxy settings come from three levels, the EnvoyGateway
config's default (here: ClusterIP Service, 1 replica, short drain), the
GatewayClass's `parametersRef`, and the Gateway's. A more specific one
**replaces** the less specific ones unless it sets `mergeType`
(`StrategicMerge` or `JSONMerge`). Without it, the Service falls back to
Envoy Gateway's built-in default, type LoadBalancer, which never gets an
address here, so the Gateway stops being Programmed.

What else lives in EnvoyProxy:
- the Deployment/DaemonSet, HPA, PDB, Service (type, annotations for cloud
  load balancers, `externalTrafficPolicy`), container image;
- telemetry: access logs (file, OpenTelemetry, gRPC ALS), metrics
  (Prometheus, OTel), tracing (OTel/Zipkin with sampling);
- `concurrency`, `shutdown` (drain timing), `bootstrap` (patch the
  bootstrap Envoy starts with), `filterOrder`, backend TLS client
  certificates, `mergeGateways` (one Envoy fleet for all Gateways of a
  class, saving memory);
- for anything else, `EnvoyPatchPolicy` patches the generated xDS
  directly (JSON Patch), the escape hatch.
