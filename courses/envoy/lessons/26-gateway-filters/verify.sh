source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
for r in api old; do
  check_eq "HTTPRoute $r is Accepted with ResolvedRefs" "True True" "$(route_cond httproute/$r Accepted) $(route_cond httproute/$r ResolvedRefs)"
done
shadow_ip="$(pod_ips app=api-shadow)"
mirrored() { gw_admin edge /clusters | awk -F'::' -v h="$shadow_ip:80" '$2==h && $3=="rq_total" {s+=$4} END{print s+0}'; }
m0="$(mirrored)"

echo "what the api backend receives for api.lab/api/v1/users?page=2"
body="$(http_body 'http://edge/api/v1/users?page=2' -H 'Host: api.lab' -H 'x-env: prod' -H 'x-debug-token: s3cr3t')"
check_eq "Answered by api (not the shadow)" "Name: api" "$(printf '%s\n' "$body" | grep '^Name:' | tr -d '\r')"
check_eq "Path without /api: GET /v1/users?page=2" "GET /v1/users?page=2 HTTP/1.1" "$(printf '%s\n' "$body" | grep -E '^GET ' | tr -d '\r')"
why "URLRewrite filter: path {type: ReplacePrefixMatch, replacePrefixMatch: /}"
check_eq "Host: api.internal" "Host: api.internal" "$(printf '%s\n' "$body" | grep '^Host:' | tr -d '\r')"
why "URLRewrite filter: hostname: api.internal"
check_eq "Exactly one x-env, value lab (the client sent prod)" "X-Env: lab" "$(printf '%s\n' "$body" | grep -i '^x-env:' | tr -d '\r' | paste -sd'|' -)"
why "RequestHeaderModifier: set overwrites, add appends."
check "No x-debug-token" eval '! printf "%s\n" "$body" | grep -qi "^x-debug-token:"'
echo "what the client receives"
check_eq "Response header x-served-by: envoy-gateway" envoy-gateway "$(http_head http://edge/api/v1/users x-served-by -H 'Host: api.lab')"
echo "mirroring"
hits_out -n 10 http://edge/api/v1/users -H 'Host: api.lab' >/dev/null
ok() { [[ $(( $(mirrored) - m0 )) -ge 11 ]]; }
wait_until 5 ok
check_ge "The shadow backend got a copy of every request (Envoy counted $(( $(mirrored) - m0 )) of 11)" 11 $(( $(mirrored) - m0 ))
why "RequestMirror filter with backendRef api-shadow:80. The client never sees the shadow's answer."
echo "old.lab"
loc="$(http_head 'http://edge/products/7?x=1' location -H 'Host: old.lab')"
check_eq "old.lab/products/7?x=1 -> https://new.lab/products/7?x=1" "https://new.lab/products/7?x=1" "$loc"
check_eq "... with status 301" 301 "$(http_code http://edge/a -H 'Host: old.lab')"
why "RequestRedirect filter: scheme https, hostname new.lab, statusCode 301 (and no backendRefs)."
