# Solution

    kubectl apply -f solution/destinationrule.yaml -f solution/virtualservice.yaml

- DestinationRule: subset `v2` selected `version: "2"`, which no Pod has. Its
  Envoy cluster `outbound|8000|v2|catalog...` had no endpoints (`istioctl
  proxy-config endpoints` shows nothing for it), so a route to it would have
  returned 503 `no healthy upstream`.
- VirtualService `catalog`: route `beta` matches `x-beta` exactly `"true"` and
  goes to `v2`; route `default` has no match and goes to `v1`. Swap them and
  every request goes to v1, because the catch-all matches first.

`istioctl proxy-config routes deploy/web -n shop --name 8000` now shows two
routes for the `catalog.shop.svc.cluster.local:8000` virtual host, both
generated from `catalog.shop`.

Takeaways:
- DestinationRule = subsets and connection policy; VirtualService = routing.
- First match wins; keep the catch-all last.
- A subset that selects nothing gives 503 `no healthy upstream`.
