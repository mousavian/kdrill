source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "HTTPRoute cart is Accepted with ResolvedRefs" "True True" "$(route_cond httproute/cart Accepted) $(route_cond httproute/cart ResolvedRefs)"
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A BackendTrafficPolicy targets HTTPRoute cart and is Accepted (got: ${btp:-none})" eval '[[ "$btp" == *"HTTPRoute/cart:True"* ]]'
check_eq "The sick pod is still behind the Service (4 endpoints)" 4 "$(pod_ips pool=echo | wc -w | tr -d ' ')"

[[ "$btp" == *"HTTPRoute/cart:True"* ]] && gw_wait_config edge dynamic_active_clusters maglev 25
echo "warm-up: 40 requests from 20 users (the sick pod should get ejected)"
for i in $(seq 1 20); do hits_out -n 2 http://edge/cart -H 'Host: shop.lab' -H "x-user: warm$i" >/dev/null; done
sick_ip="$(pod_ips app=sick)"
ejected() { gw_admin edge /clusters | awk -F'::' -v h="$sick_ip:80" '$2==h && $3=="health_flags" {print $4}' | grep -q failed_outlier_check; }
wait_until 6 ejected; ej=$?
check "The sick pod is ejected (/failed_outlier_check in the Gateway Envoy's /clusters)" test $ej = 0
why "healthCheck.passive: {consecutive5XxErrors: 3, baseEjectionTime: 30s, maxEjectionPercent: 50}"

echo "stickiness: 8 users x 6 requests"
used=""; split=""; fails=0
for u in alice bob carol dave erin frank grace heidi; do
  out="$(hits_out -p -n 6 http://edge/cart -H 'Host: shop.lab' -H "x-user: $u")"
  w="$(whos "$out")"; ok="$(count_of "200 *" "$out")"
  fails=$((fails + 6 - ok))
  [[ "$(echo $w | wc -w | tr -d ' ')" == 1 ]] || split+="$u "
  used+="$w "
done
check_eq "No errors (got $fails failed requests)" 0 "$fails"
check_eq "Each user's requests all went to one pod" "" "$split"
why "loadBalancer: {type: ConsistentHash, consistentHash: {type: Header, header: {name: x-user}}}"
check_ge "The users are spread over at least 2 pods" 2 "$(echo $used | tr ' ' '\n' | sort -u | grep -c .)"
