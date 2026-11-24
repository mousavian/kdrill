source "$KDRILL_HOME/courses/istio/lib.sh"
GW=http://shop-gateway-istio.shop.svc.cluster.local
H="Host: shop.example.com"
TOK="$KDRILL_LESSON_DIR/probes/tokens"
tok() { tr -d '\n' < "$TOK/$1.jwt"; }
# call PATH [TOKEN] -> status code through the gateway, from outside the mesh
call() { if [[ -n "${2:-}" ]]; then http_code outside visitor "$GW$1" -H "$H" -H "Authorization: Bearer $(tok "$2")"; else http_code outside visitor "$GW$1" -H "$H"; fi; }
rollouts shop shop-gateway-istio
settle 2
await_code 10 403 outside visitor $GW/anything/orders/1 -H "$H"

echo "setup unchanged"
check_eq "Gateway shop-gateway is Programmed" True "$(jp gateway.gateway.networking.k8s.io/shop-gateway '{.status.conditions[?(@.type=="Programmed")].status}' -n shop)"

echo "public"
check_eq "/anything/public/menu without a token -> 200" 200 "$(call /anything/public/menu)"
echo "orders: a valid token is required"
check_eq "/anything/orders/1 without a token -> 403" 403 "$(call /anything/orders/1)"
why "RequestAuthentication alone lets token-less requests through; an AuthorizationPolicy with requestPrincipals makes the token mandatory."
check_eq "/anything/orders/1 with alice's token -> 200" 200 "$(call /anything/orders/1 alice)"
body="$(http_body outside visitor $GW/anything/orders/1 -H "$H" -H "Authorization: Bearer $(tok alice)")"
check "orders receives the user name in header X-User: alice" grep -qiE '"X-User": *\[ *"alice"' <<<"$(tr -d '\n' <<<"$body")"
why "RequestAuthentication jwtRules[].outputClaimToHeaders: [{header: x-user, claim: sub}]"
echo "invalid tokens are rejected (401)"
check_eq "expired token -> 401" 401 "$(call /anything/orders/1 expired)"
check_eq "token signed with someone else's key -> 401" 401 "$(call /anything/orders/1 forged)"
check_eq "token from another issuer -> 401" 401 "$(call /anything/orders/1 other-issuer)"
echo "admin API: group admins"
check_eq "/anything/admin/stats with alice's token (customers) -> 403" 403 "$(call /anything/admin/stats alice)"
check_eq "/anything/admin/stats with root's token (admins) -> 200" 200 "$(call /anything/admin/stats root)"
why "when: [{key: request.auth.claims[groups], values: [admins]}]"
