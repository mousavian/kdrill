source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "Gateway edge is programmed" True "$(gw_cond edge Programmed)"

echo "the route"
check_eq "HTTPRoute shop: Accepted and ResolvedRefs" "True True" "$(route_cond httproute/shop Accepted) $(route_cond httproute/shop ResolvedRefs)"
why "kubectl get httproute shop -o yaml: the ResolvedRefs condition names the broken backendRef."
check_eq "Service cart still listens on port 80 (fix the route, not the Service)" 80 "$(jp svc/cart '{.spec.ports[0].port}')"
out="$(hits_out -n 10 http://edge/cart/items -H 'Host: shop.lab')"
check_eq "shop.lab/cart/items -> 10 x 200 from cart" 10 "$(count_of "200 cart" "$out")"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -)"
out="$(hits_out -n 5 http://edge/ -H 'Host: shop.lab')"
check_eq "shop.lab/ -> 5 x 200 from web" 5 "$(count_of "200 web" "$out")"

echo "answers (ConfigMap answers, compared with the Gateway's Envoy)"
L="$(gw_admin edge /listeners)"
want_listener="$(printf '%s\n' "$L" | grep '^lab/edge/' | cut -d: -f1)"
want_port="$(printf '%s\n' "$L" | grep '^lab/edge/' | sed 's/.*://')"
R="$(gw_admin edge '/config_dump?resource=dynamic_route_configs' | tr -d ' \n')"
want_vhost="$(printf '%s' "$R" | grep -o '"name":"lab/edge/http/shop[^"]*"' | head -n 1 | cut -d'"' -f4)"
want_cluster="$(printf '%s' "$R" | grep -o '"prefix":"/cart"[^}]*}*,"route":{"cluster":"[^"]*"' | grep -o '"cluster":"[^"]*"' | cut -d'"' -f4)"
want_eps="$(gw_admin edge /clusters | awk -F'::' -v c="$want_cluster" '$1==c && $3=="cx_active" {print $2}' | sort | paste -sd' ' -)"
ans() { kubectl get configmap answers -o jsonpath="{.data.$1}" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//'; }
sorted() { echo "$1" | tr ' ' '\n' | grep . | sort | paste -sd' ' -; }
check "ConfigMap answers exists" kubectl get configmap answers
check_eq "listener: the Envoy listener of Gateway listener http" "$want_listener" "$(ans listener)"
why "gw admin /listeners (kubectl port-forward deploy/edge 19000, then curl localhost:19000/listeners)"
check_eq "port: the port that Envoy listener binds inside the pod" "$want_port" "$(ans port)"
why "The Gateway says 80; Envoy runs as non-root and can't bind ports below 1024."
check_eq "virtual_host: the virtual host for shop.lab" "$want_vhost" "$(ans virtual_host)"
why "config_dump?resource=dynamic_route_configs: one virtual host per hostname"
check_eq "cart_cluster: the cluster that the /cart rule routes to" "$want_cluster" "$(ans cart_cluster)"
check_eq "cart_endpoints: its endpoints as ip:port, space-separated" "$want_eps" "$(sorted "$(ans cart_endpoints)")"
why "/clusters lists each host; they are pod IPs and the pods' port (EDS from EndpointSlices), not the Service's ClusterIP."
