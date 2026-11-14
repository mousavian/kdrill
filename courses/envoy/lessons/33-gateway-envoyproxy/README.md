# EnvoyProxy: customise the Gateway's Envoy fleet

## Concept

The Gateway API describes listeners and routes; it doesn't say how the
proxies run. In Envoy Gateway that's the **EnvoyProxy** resource:

- **infrastructure**: Deployment or DaemonSet, replicas, HPA, pod labels
  and annotations, resources, image; the Service type and annotations
  (cloud load balancer settings); `concurrency`; shutdown and draining;
- **telemetry**: access logs (format, sinks, matching), metrics, tracing;
- **Envoy internals**: bootstrap patches, HTTP filter order, merged
  Gateways (one fleet serving all Gateways of a class).

It is referenced at three levels, from least to most specific: the
default in the EnvoyGateway config (this lab sets ClusterIP Service, one
replica, one worker thread, short drain), a GatewayClass's
`parametersRef`, and a Gateway's `spec.infrastructure.parametersRef`. A
more specific EnvoyProxy **replaces** the less specific ones entirely,
unless it sets `mergeType: StrategicMerge` (or `JSONMerge`).

Changing pod-level settings rolls the Envoy Deployment; changing
telemetry is pushed over xDS like any other config.

This split mirrors team responsibilities: app teams own routes and their
policies, the platform team owns GatewayClasses and EnvoyProxy defaults
(observability, sizing, exposure) for everyone. When a setting you need
isn't exposed anywhere, `EnvoyPatchPolicy` can patch the generated xDS
directly, as a last resort.

## The situation

Gateway `edge` (HTTPRoute `web` for `www.lab`) uses only the cluster
defaults. Its Envoy logs Envoy Gateway's default JSON format. The platform
team wants every Envoy to log a fixed set of fields, carry a team label,
and request less memory.

## Your task

Create an EnvoyProxy and reference it from the Gateway `edge` so that:

- the Gateway stays Programmed with a ClusterIP Service;
- the Envoy pod has the label `team: platform` and its `envoy` container
  requests `40Mi` of memory;
- the access log goes to stdout as JSON with exactly the keys `status`,
  `method`, `path` (incl. query), `upstream`, `flags`, `duration_ms` and
  `request_id`.

## Useful commands

    kubectl explain envoyproxy.spec.provider.kubernetes.envoyDeployment
    kubectl explain envoyproxy.spec.telemetry.accessLog.settings
    kubectl get gateway edge; kubectl get svc edge; kubectl get pods --show-labels
    kubectl exec client -- curl -s -o /dev/null http://edge/products?id=7 -H 'Host: www.lab'
    kubectl logs deploy/edge -c envoy --tail=2

When you think you're done: `kdrill verify` (up to 15 s: Envoy flushes file access logs every 10 s).

## On a real cluster

The default Service type is LoadBalancer and the EnvoyProxy usually
carries cloud load balancer annotations, several replicas, an HPA and a PDB.
The lab's defaults (ClusterIP, one small replica) are set in the
component's EnvoyGateway config.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/operations/customize-envoyproxy/
- https://gateway.envoyproxy.io/v1.9/tasks/observability/proxy-accesslog/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#envoyproxy
- https://gateway.envoyproxy.io/v1.9/tasks/extensibility/envoy-patch-policy/
