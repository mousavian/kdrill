source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "HTTPRoute api is Accepted with ResolvedRefs" "True True" "$(route_cond httproute/api Accepted) $(route_cond httproute/api ResolvedRefs)"
timed() { kx curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time 20 -H 'Host: api.lab' "$1" | awk '{printf "%s %.1f", $1, $2}'; }

echo "timeouts"
r="$(timed 'http://edge/api/items?wait=3s')"
check_eq "/api/items?wait=3s -> 504" 504 "${r% *}"
why "rules[].timeouts.request: 1s on the /api rule"
check "... after about 1 s (took ${r#* }s)" awk -v t="${r#* }" 'BEGIN{exit !(t>=0.8 && t<=1.9)}'
r="$(timed 'http://edge/reports/daily?wait=3s')"
check_eq "/reports/daily?wait=3s -> 200" 200 "${r% *}"
why "timeouts.request: 10s on the /reports rule. If you only got 503 'broken', that's the sick pod: retries fix that."
t="$(kubectl get httproute api -o jsonpath='{range .spec.rules[*]}{.matches[0].path.value}={.timeouts.request}{" "}{end}' 2>/dev/null)"
check "The timeouts are set on the HTTPRoute rules (/api=1s, /reports=10s; got: $t)" eval '[[ " $t " == *" /api=1s "* && " $t " == *" /reports=10s "* ]]'

echo "retries (BackendTrafficPolicy)"
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A BackendTrafficPolicy targets HTTPRoute api and is Accepted (got: ${btp:-none})" eval '[[ "$btp" == *":HTTPRoute/api:True"* ]]'
why "spec.targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: api}]; kubectl get backendtrafficpolicy -o yaml shows status.ancestors."
retries() { gw_admin edge '/stats?filter=upstream_rq_retry$' | awk -F': ' '/httproute\/lab\/api/ {s+=$2} END{print s+0}'; }
r0="$(retries)"
out="$(hits_out -n 60 http://edge/api/items -H 'Host: api.lab')"
r1="$(retries)"
check_eq "60 GETs to /api: all 200" 60 "$(count_of "200 *" "$out")"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -). retry: {numRetries: 2, retryOn: {triggers: [retriable-status-codes], httpStatusCodes: [503]}}"
check_ge "Envoy retried (upstream_rq_retry +$((r1 - r0)))" 5 $((r1 - r0))
check_eq "The sick pod is still a backend of the echo Service" "1" "$(kubectl get pods -l pool=echo,app=sick --no-headers 2>/dev/null | wc -l | tr -d ' ')"
