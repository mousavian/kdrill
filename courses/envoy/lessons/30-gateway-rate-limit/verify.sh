source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.spec.rateLimit.type}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A BackendTrafficPolicy with a Local rateLimit targets HTTPRoute api and is Accepted (got: ${btp:-none})" eval '[[ "$btp" == *"HTTPRoute/api:Local:True"* ]]'
[[ "$btp" == *"HTTPRoute/api:Local:True"* ]] && gw_wait_config edge dynamic_route_configs local_ratelimit 15
echo "a burst of 12 without a plan"
out="$(hits_out -n 12 http://edge/items -H 'Host: api.lab')"
ok="$(count_of "200 *" "$out")"; rl="$(count_of "429 *" "$out")"
check "At most 5 succeeded (got $ok)" test "$ok" -le 5
check_ge "The others got 429" 7 "$rl"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -). rateLimit: {type: Local, local: {rules: [{limit: {requests: 5, unit: Minute}}]}}"
echo "a burst of 12 with x-plan: gold"
out="$(hits_out -n 12 http://edge/items -H 'Host: api.lab' -H 'x-plan: gold')"
check_eq "All 12 succeeded (gold has its own budget of 30/min)" 12 "$(count_of "200 *" "$out")"
why "A rule with clientSelectors [{headers: [{name: x-plan, value: gold}]}] and limit 30/Minute, listed before the catch-all rule. (Run verify again after a minute if you've used the gold budget up.)"
check_ge "Envoy counted rate-limited requests" 7 "$(gw_admin edge '/stats?filter=rate_limited$' | awk -F': ' '{s+=$2} END{print s+0}')"
