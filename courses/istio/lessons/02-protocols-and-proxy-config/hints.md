Compare what the sidecar of `frontend` built for the two Services:

    istioctl proxy-config listeners deploy/frontend -n store --port 8000
    istioctl proxy-config routes deploy/frontend -n store

An HTTP Service shows up under a `0.0.0.0_8000` listener with an HTTP route;
a TCP Service gets its own `<ClusterIP>_8000` listener with a TCP proxy.
---
Istio decides the protocol of a Service port from, in order:
`appProtocol` (http, http2, grpc, tcp, ...), then the port name prefix
(`http-...`, `grpc-...`, `tcp-...`), then auto-detection for unnamed ports.

- `catalog`: the port name starts with `tcp-`.
- `reviews`: `appProtocol: tcp` overrides the name.
---
    kubectl apply -f solution/services.yaml       # from the lesson directory

Renames catalog's port to `http-web` and sets `appProtocol: http` on
reviews. No restart is needed: istiod pushes new listeners within seconds.
