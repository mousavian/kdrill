source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
GW=http://shop-gateway-istio.shop.svc.cluster.local
H="Host: shop.example.com"
rollouts $NS shop-gateway-istio
settle 2
# A new gateway Envoy can be Ready a moment before istiod has pushed its routes.
await_code 15 200 outside visitor $GW/hostname -H "$H"

echo "gateway"
check_eq "Gateway shop-gateway uses gatewayClassName istio" istio "$(jp gateway.gateway.networking.k8s.io/shop-gateway '{.spec.gatewayClassName}' -n $NS)"
check_eq "Gateway shop-gateway is Programmed" True "$(jp gateway.gateway.networking.k8s.io/shop-gateway '{.status.conditions[?(@.type=="Programmed")].status}' -n $NS)"
why "kubectl -n shop describe gateway shop-gateway shows why not."
check_eq "Istio deployed the gateway (Deployment shop-gateway-istio ready)" 1 "$(jp deploy/shop-gateway-istio '{.status.readyReplicas}' -n $NS)"
check_eq "Its Service is ClusterIP (annotation networking.istio.io/service-type)" ClusterIP "$(jp svc/shop-gateway-istio '{.spec.type}' -n $NS)"
why "This cluster has no load balancer, so a LoadBalancer Service would stay <pending> and the Gateway never gets an address."

echo "route"
check_eq "HTTPRoute shop is Accepted by shop-gateway" True "$(jp httproute/shop '{.status.parents[0].conditions[?(@.type=="Accepted")].status}' -n $NS)"
check_eq "HTTPRoute shop has its backends resolved (ResolvedRefs)" True "$(jp httproute/shop '{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' -n $NS)"
why "kubectl -n shop get httproute shop -o yaml - look at status.parents[].conditions."

echo "traffic (from namespace outside, no sidecar)"
check_eq "shop.example.com/hostname is answered by web" "web:3" "$(backends outside visitor $GW/hostname 3 -H "$H")"
check_eq "shop.example.com/api/hostname is answered by api, as /hostname" "api:3" "$(backends outside visitor $GW/api/hostname 3 -H "$H")"
why "api has no /api/... paths: the route must strip the prefix (URLRewrite ReplacePrefixMatch: /)."
check_eq "shop.example.com/api/status/418 reaches api's /status/418" 418 "$(http_code outside visitor $GW/api/status/418 -H "$H")"
check_eq "Another host (evil.example.com) is not served: 404" 404 "$(http_code outside visitor $GW/hostname -H "Host: evil.example.com")"
why "Set hostname on the listener and/or hostnames on the HTTPRoute."
