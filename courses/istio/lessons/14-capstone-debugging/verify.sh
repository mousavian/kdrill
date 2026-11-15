source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
GW=http://shop-gateway-istio.shop.svc.cluster.local
H="Host: shop.example.com"
rollouts $NS shop-gateway-istio
settle 2
await_code 10 200 outside visitor $GW/pay/anything/charge -H "$H"

echo "ingress (outside/visitor -> gateway)"
check_eq "shop.example.com/catalog/get -> 200" 200 "$(http_code outside visitor $GW/catalog/get -H "$H")"
check_eq "shop.example.com/pay/anything/charge -> 200 (payments answers)" 200 "$(http_code outside visitor $GW/pay/anything/charge -H "$H")"
why "Follow the request: route status, then the gateway's logs/stats, then payments' sidecar. It can fail at more than one place."

echo "version routing (web -> catalog)"
check_eq "5 requests with x-beta: true -> catalog-v2" "catalog-v2:5" "$(backends $NS web http://catalog:8000/hostname 5 -H 'x-beta: true')"
check_eq "10 requests without it -> catalog-v1" "catalog-v1:10" "$(backends $NS web http://catalog:8000/hostname 10)"
why "The VirtualService looks right. Is Istio treating catalog's traffic as HTTP at all?"

echo "payments (web -> payments)"
hdrs="$(http_body $NS web http://payments:8000/headers)"
check "web reaches payments over mTLS (payments sees spiffe://cluster.local/ns/shop/sa/web)" grep -q 'URI=spiffe://cluster.local/ns/shop/sa/web' <<<"$hdrs"
why "A 503 with 'connection reset' means the two sidecars disagree on TLS. Who decides what the client sends?"

echo "security is not weakened"
check_eq "PeerAuthentication default in shop is still STRICT" STRICT "$(jp peerauthentication/default '{.spec.mtls.mode}' -n $NS)"
check_eq "A plaintext client outside the mesh is still rejected by payments" 000 "$(http_code outside visitor http://payments.shop:8000/get)"
check_eq "scanner (shop) is still denied by payments: 403" 403 "$(http_code $NS scanner http://payments:8000/get)"
check_eq "AuthorizationPolicy payments is still an ALLOW policy for app=payments" "ALLOW payments" \
  "$(jp authorizationpolicy/payments '{.spec.action} {.spec.selector.matchLabels.app}' -n $NS)"
check_eq "Workloads unchanged (catalog-v1, catalog-v2, payments: 1 replica each, ready)" "1 1 1" \
  "$(jp deploy/catalog-v1 '{.status.readyReplicas}' -n $NS) $(jp deploy/catalog-v2 '{.status.readyReplicas}' -n $NS) $(jp deploy/payments '{.status.readyReplicas}' -n $NS)"
