source "$KDRILL_HOME/courses/envoy/lib.sh"
SEL='{.spec.listeners[?(@.name=="http")].allowedRoutes.namespaces'
_storefront_ok() {
  [[ "$(jp httproute/storefront '{.status.parents[*].conditions[?(@.type=="Accepted")].status}')" == True ]] \
    && [[ "$(jp httproute/storefront '{.status.parents[*].conditions[?(@.type=="ResolvedRefs")].status}')" == True ]]
}
# Give a just-made change a moment, but only when there is something to wait for.
if [[ "$(jp gateway/public "$SEL.from}" -n infra)" == Selector && "$(jp ns/lab '{.metadata.labels.gateway-access}')" == public ]]; then
  wait_until 20 _storefront_ok || true
fi
sleep 1

echo "Gateway public (namespace infra)"
check_eq "Listener http admits routes by namespace selector" Selector "$(jp gateway/public "$SEL.from}" -n infra)"
why "spec.listeners[].allowedRoutes.namespaces: from: Selector, with a selector. 'All' would let sandbox in too."
check_eq "... and the selector is gateway-access=public" public \
  "$(jp gateway/public "$SEL.selector.matchLabels.gateway-access}" -n infra)"
check_eq "Namespace lab carries gateway-access=public" public "$(jp ns/lab '{.metadata.labels.gateway-access}')"
check_eq "Namespace sandbox does not" "" "$(jp ns/sandbox '{.metadata.labels.gateway-access}')"
check_eq "Listener hostname is still *.lab" "*.lab" "$(jp gateway/public '{.spec.listeners[?(@.name=="http")].hostname}' -n infra)"
check_eq "Gateway public is Programmed" True "$(jp gateway/public '{.status.conditions[?(@.type=="Programmed")].status}' -n infra)"

echo "routes"
check_eq "HTTPRoute lab/storefront is Accepted by the Gateway" True \
  "$(jp httproute/storefront '{.status.parents[*].conditions[?(@.type=="Accepted")].status}')"
why "kubectl describe httproute storefront: NotAllowedByListeners means the listener's allowedRoutes does not admit namespace lab."
check_eq "HTTPRoute lab/storefront has ResolvedRefs (may use Service reviews/reviews)" True \
  "$(jp httproute/storefront '{.status.parents[*].conditions[?(@.type=="ResolvedRefs")].status}')"
why "RefNotPermitted: a reference to another namespace needs a ReferenceGrant in the target namespace (reviews)."
check "HTTPRoute sandbox/sneaky is NOT accepted" \
  test "$(jp httproute/sneaky '{.status.parents[*].conditions[?(@.type=="Accepted")].status}' -n sandbox)" != True

echo "traffic (from the client pod to http://public.infra)"
G=http://public.infra
out="$(hits_out -n 10 $G/ -H 'Host: shop.lab')"
check_eq "shop.lab/ -> 10 x 200 from web" 10 "$(count_of "200 web" "$out")"
out="$(hits_out -n 10 $G/reviews/list -H 'Host: shop.lab')"
check_eq "shop.lab/reviews/list -> 10 x 200 from reviews" 10 "$(count_of "200 reviews" "$out")"
why "Without a ReferenceGrant the rule exists but Envoy Gateway answers 500 for it."
check_eq "shop.lab/admin is not served by sandbox's experiment (404)" 404 "$(http_code $G/admin -H 'Host: shop.lab')"
