source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
sp="$(kubectl get securitypolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A SecurityPolicy targets HTTPRoute api and is Accepted (got: ${sp:-none})" eval '[[ "$sp" == *"HTTPRoute/api:True"* ]]'
why "kubectl get securitypolicy -o yaml: status.ancestors[].conditions says why not."
[[ "$sp" == *"HTTPRoute/api:True"* ]] && gw_wait_config edge dynamic_listeners jwt_authn 15
U=http://edge/api/orders
as() { local who="$1"; shift; http_code "$@" -H 'Host: api.lab' -H "Authorization: Bearer $(token "$who")"; }
echo "authentication"
check_eq "No token -> 401" 401 "$(http_code $U -H 'Host: api.lab')"
check_eq "alice GET -> 200" 200 "$(as alice $U)"
check_eq "Expired token -> 401" 401 "$(as expired $U)"
check_eq "Forged token -> 401" 401 "$(as forged $U)"
check_eq "Token for audience billing -> 403" 403 "$(as wrong-aud $U)"
why "jwt.providers: issuer https://auth.lab, audiences [shop], localJWKS from the ConfigMap jwks"
body="$(http_body $U -H 'Host: api.lab' -H "Authorization: Bearer $(token alice)" -H 'x-user: bob')"
check_eq "The backend gets x-user: alice (from sub, replacing a client-sent x-user)" "X-User: alice" "$(printf '%s\n' "$body" | grep -i '^x-user:' | tr -d '\r' | paste -sd'|' -)"
why "claimToHeaders: [{claim: sub, header: x-user}]"
echo "authorization"
check_eq "alice (viewer) DELETE -> 403" 403 "$(as alice $U/1 -X DELETE)"
check_eq "alice (viewer) POST -> 403" 403 "$(as alice $U -X POST)"
why "authorization: defaultAction Deny; allow GET/HEAD for any valid token; allow everything for role admin."
check_eq "bob (admin) DELETE -> 200" 200 "$(as bob $U/1 -X DELETE)"
check_eq "bob (admin) POST -> 200" 200 "$(as bob $U -X POST)"
