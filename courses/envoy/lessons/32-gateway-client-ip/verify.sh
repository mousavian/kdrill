source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
st() { kubectl get "$1" -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null; }
ctp="$(st clienttrafficpolicy)"; sp="$(st securitypolicy)"
check "A ClientTrafficPolicy targets Gateway edge and is Accepted (got: ${ctp:-none})" eval '[[ "$ctp" == *"Gateway/edge:True"* ]]'
check "A SecurityPolicy targets HTTPRoute admin and is Accepted (got: ${sp:-none})" eval '[[ "$sp" == *"HTTPRoute/admin:True"* ]]'
[[ "$sp" == *"HTTPRoute/admin:True"* ]] && gw_wait_config edge dynamic_route_configs rbac 15
A=http://edge/admin/users
xff() { http_code "$A" -H 'Host: www.lab' ${1:+-H "X-Forwarded-For: $1"}; }
echo "/admin (the client pod plays the load balancer and sets X-Forwarded-For)"
check_eq "XFF 203.0.113.7 (office) -> 200" 200 "$(xff 203.0.113.7)"
why "Envoy must take the client IP from X-Forwarded-For (ClientTrafficPolicy clientIPDetection.xForwardedFor.numTrustedHops: 1) and the SecurityPolicy must allow 203.0.113.0/24."
check_eq "XFF 198.51.100.9 (internet) -> 403" 403 "$(xff 198.51.100.9)"
check_eq "No XFF (the load balancer's own address) -> 403" 403 "$(xff)"
check_eq "Spoofing: client sends XFF 203.0.113.7, the LB appends 198.51.100.9 -> 403" 403 "$(xff '203.0.113.7, 198.51.100.9')"
why "Only the hop added by your trusted proxy (the rightmost entry with numTrustedHops 1) is believable; anything to its left came from the client."
echo "the rest of the site"
check_eq "XFF 198.51.100.9, GET / -> 200 (only /admin is restricted)" 200 "$(http_code http://edge/ -H 'Host: www.lab' -H 'X-Forwarded-For: 198.51.100.9')"
rid="kdrill-$RANDOM$RANDOM"
http_code http://edge/ -H 'Host: www.lab' -H 'X-Forwarded-For: 203.0.113.7' -H "x-request-id: $rid" >/dev/null
logged() { kubectl logs deploy/edge -c envoy --since=60s 2>/dev/null | grep -F "\"$rid\"" | grep -o '"downstream_remote_address":"[^"]*"' | cut -d'"' -f4 | cut -d: -f1; }
seen() { [[ -n "$(logged)" ]]; }
wait_until 13 seen   # file access logs are flushed every 10 s
check_eq "The Gateway's access log records the client as 203.0.113.7 (downstream_remote_address)" 203.0.113.7 "$(logged)"
