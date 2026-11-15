source "$KDRILL_HOME/courses/istio/lib.sh"
L=http://ledger.bank:8000
settle 2
await_code 10 403 shop scanner $L/anything/accounts/42

# req FROM METHOD PATH -> status code
req() { http_code shop "$1" "$L$3" -X "$2"; }

echo "default deny"
empty="$(kubectl -n bank get authorizationpolicy -o jsonpath='{range .items[*]}{.metadata.name}={.spec}{"\n"}{end}' 2>/dev/null | grep -E '=(\{\})?$' | cut -d= -f1 | paste -sd' ' -)"
check "bank has an allow-nothing policy (empty spec: applies to all workloads, allows nothing)" test -n "$empty"
why "apiVersion: security.istio.io/v1, kind: AuthorizationPolicy, spec: {} in namespace bank."

echo "web (read accounts only)"
check_eq "web GET  /anything/accounts/42 -> 200" 200 "$(req web GET /anything/accounts/42)"
check_eq "web POST /anything/accounts/42 -> 403" 403 "$(req web POST /anything/accounts/42)"
check_eq "web GET  /anything/admin/users -> 403" 403 "$(req web GET /anything/admin/users)"
check_eq "web GET  /get (not an accounts path) -> 403" 403 "$(req web GET /get)"
echo "admin (accounts + admin API, any method)"
check_eq "admin GET  /anything/admin/users -> 200" 200 "$(req admin GET /anything/admin/users)"
check_eq "admin POST /anything/accounts/42 -> 200" 200 "$(req admin POST /anything/accounts/42)"
check_eq "admin PUT  /anything/admin/users/7 -> 200" 200 "$(req admin PUT /anything/admin/users/7)"
echo "nobody deletes accounts"
check_eq "admin DELETE /anything/accounts/42 -> 403" 403 "$(req admin DELETE /anything/accounts/42)"
why "A DENY policy is evaluated before ALLOW policies; an ALLOW rule cannot override it."
echo "everyone else"
check_eq "scanner GET /anything/accounts/42 -> 403" 403 "$(req scanner GET /anything/accounts/42)"
body="$(http_body shop scanner $L/anything/accounts/42)"
check "The 403 comes from the ledger's sidecar (body: RBAC: access denied)" grep -q 'RBAC: access denied' <<<"$body"
