source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge

echo "Gateway edge"
check_eq "Accepted by its GatewayClass" True "$(gw_cond edge Accepted)"
why "kubectl get gatewayclass shows the classes that exist; kubectl describe gateway edge shows why it isn't accepted."
check_eq "Programmed (Envoy Gateway created and configured its Envoy)" True "$(gw_cond edge Programmed)"
check "It has an address (the ClusterIP of the Service edge)" test -n "$(jp gateway/edge '{.status.addresses[0].value}')"
check "Its Envoy pod runs in this namespace (Deployment edge)" test -n "$(gw_pod edge)"
check_eq "Listener http has 2 routes attached" 2 "$(jp gateway/edge '{.status.listeners[?(@.name=="http")].attachedRoutes}')"
why "A route attaches when its parentRefs name the Gateway and the listener's allowedRoutes permit it."

echo "HTTPRoutes"
for r in web api; do
  check_eq "HTTPRoute $r: parent edge, Accepted and ResolvedRefs" "edge True True" \
    "$(jp httproute/$r '{.status.parents[0].parentRef.name}') $(route_cond httproute/$r Accepted) $(route_cond httproute/$r ResolvedRefs)"
done

echo "traffic (from the client pod to http://edge)"
for s in web api; do
  h=www.lab; [[ $s == api ]] && h=api.lab
  out="$(hits_out -n 10 http://edge/products -H "Host: $h")"
  check_eq "Host $h -> 10 x 200 from $s" 10 "$(count_of "200 $s" "$out")"
done
check_eq "Host other.lab -> 404" 404 "$(http_code http://edge/ -H 'Host: other.lab')"
