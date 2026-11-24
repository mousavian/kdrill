An EnvoyProxy resource describes how Envoy Gateway runs and configures a
Gateway's Envoy fleet. A Gateway points to one with

    spec:
      infrastructure:
        parametersRef: {group: gateway.envoyproxy.io, kind: EnvoyProxy, name: edge-proxy}

`kubectl explain envoyproxy.spec.provider.kubernetes.envoyDeployment` and
`kubectl explain envoyproxy.spec.telemetry.accessLog`.
---
If the Gateway stops being Programmed after you attach your EnvoyProxy,
look at `kubectl get svc edge`: an EnvoyProxy replaces the defaults of the
EnvoyGateway config (which made the Service ClusterIP) unless it has
`mergeType: StrategicMerge`. A LoadBalancer Service never gets an address
in this lab.

Access log: `settings: [{format: {type: JSON, json: {status: "%RESPONSE_CODE%", ...}}, sinks: [{type: File, file: {path: /dev/stdout}}]}]`.
---
    kubectl apply -f solution/edge.yaml      # from the lesson directory
