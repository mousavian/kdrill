# Solution

    kubectl apply -f solution/services.yaml       # from the lesson directory

- `catalog`: port name `tcp-web` -> `http-web`. The `tcp-` prefix declared the
  port as opaque TCP.
- `reviews`: `appProtocol: tcp` -> `appProtocol: http`. `appProtocol` takes
  precedence over the port name, so the harmless-looking name `web` did not
  matter.

What changes in `frontend`'s sidecar (`istioctl proxy-config listeners
deploy/frontend -n store --port 8000`):

- before: one listener per Service, `10.43.x.y_8000`, each with a
  `tcp_proxy` filter straight to the cluster. No route table mentions
  catalog or reviews.
- after: both are served by the shared `0.0.0.0_8000` listener with the HTTP
  connection manager; route table `8000` has virtual hosts
  `catalog.store.svc.cluster.local:8000` (with the VirtualService's
  `x-route` header action) and `reviews.store.svc.cluster.local:8000`.

The clusters (`outbound|8000||catalog.store.svc.cluster.local`) and their
endpoints exist in both cases; only the listener/route side differs.

Takeaways:
- Name Service ports `http-...` / `grpc-...` or set `appProtocol`. Do not
  rely on sniffing.
- When an Istio feature "does nothing", check the protocol first.
- listeners -> routes -> clusters -> endpoints is the path of every request;
  `istioctl proxy-config` shows each step.
