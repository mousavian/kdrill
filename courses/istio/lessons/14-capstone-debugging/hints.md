Reproduce every symptom and note who answered (status and body):

    kubectl -n outside exec deploy/visitor -c curl -- curl -s -w '\n%{http_code}\n' -H 'Host: shop.example.com' shop-gateway-istio.shop/pay/anything/charge
    kubectl -n shop exec deploy/web -c curl -- curl -s -w '\n%{http_code}\n' payments:8000/get
    kubectl -n shop exec deploy/web -c curl -- curl -s -H 'x-beta: true' catalog:8000/hostname
    istioctl proxy-config listeners deploy/web -n shop --port 8000
    istioctl proxy-config clusters deploy/web -n shop --fqdn payments.shop.svc.cluster.local -o json | grep transport_sockets

None of these bugs makes a resource invalid, so `istioctl analyze` and the
route status stay quiet. Compare what you wrote with what the proxies got.
---
There are four bugs, each from an earlier lesson:

- the HTTPRoute points a backend at a port the Service doesn't have (03);
- catalog's Service port is declared as plain TCP (02);
- a DestinationRule tells callers how to talk TLS to payments, and it
  contradicts the PeerAuthentication (09);
- the AuthorizationPolicy names the gateway by the wrong identity (10):
  `kubectl -n shop get pod -l gateway.networking.k8s.io/gateway-name=shop-gateway -o jsonpath='{..serviceAccountName}'`.
---
    kubectl apply -f solution/services.yaml -f solution/mesh.yaml -f solution/gateway.yaml

Every fix is marked `# FIX n` in the solution files.
