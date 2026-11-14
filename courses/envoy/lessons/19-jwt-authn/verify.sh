source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
U=http://envoy:10000
auth() { echo "Authorization: Bearer $(token "$1")"; }

echo "/public/ needs no token"
check_eq "GET /public/info without a token -> 200" 200 "$(http_code $U/public/info)"
echo "/api/ needs a valid token"
check_eq "No token -> 401" 401 "$(http_code $U/api/orders)"
why "The jwt_authn filter before the router, with a rule {match: {prefix: /api/}, requires: {provider_name: ...}}"
check_eq "alice's token -> 200" 200 "$(http_code $U/api/orders -H "$(auth alice)")"
check_eq "Expired token -> 401" 401 "$(http_code $U/api/orders -H "$(auth expired)")"
check_eq "Token signed with another key (forged) -> 401" 401 "$(http_code $U/api/orders -H "$(auth forged)")"
why "Verify signatures with the issuer's keys: local_jwks {filename: /certs/jwks.json}"
check_eq "Token for another audience (billing) -> 403" 403 "$(http_code $U/api/orders -H "$(auth wrong-aud)")"
why "provider: issuer https://auth.lab, audiences [shop]"
echo "what the backend receives with alice's token"
body="$(http_body $U/api/orders -H "$(auth alice)")"
check_eq "x-user: alice (from the sub claim)" "X-User: alice" "$(printf '%s\n' "$body" | grep -i '^x-user:' | tr -d '\r')"
why "claim_to_headers: [{header_name: x-user, claim_name: sub}]"
check "No Authorization header (the raw token stays at the edge)" eval '! printf "%s\n" "$body" | grep -qi "^authorization:"'
body="$(http_body $U/api/orders -H "$(auth alice)" -H 'x-user: bob')"
check_eq "A client-sent x-user: bob is replaced by alice" "X-User: alice" "$(printf '%s\n' "$body" | grep -i '^x-user:' | tr -d '\r' | paste -sd'|' -)"
