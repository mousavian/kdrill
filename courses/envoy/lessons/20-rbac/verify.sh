source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
U=http://envoy:10000
as() { local who="$1"; shift; http_code "$@" -H "Authorization: Bearer $(token "$who")"; }
row() { # row EXPECTED WHO METHOD PATH [curl options]
  local exp="$1" who="$2" m="$3" p="$4"; shift 4
  local got
  if [[ "$who" == - ]]; then got="$(http_code "$U$p" -X "$m" "$@")"; else got="$(as "$who" "$U$p" -X "$m" "$@")"; fi
  check_eq "$(printf '%-6s %-6s %-20s' "$who" "$m" "$p") -> $exp" "$exp" "$got"
}
echo "public"
row 200 - GET /public/info
echo "alice (role viewer)"
row 200 alice GET /api/orders
row 403 alice POST /api/orders
why "Writes need role admin. The RBAC filter (after jwt_authn, before the router) with action ALLOW and policies."
row 403 alice DELETE /api/orders/1
row 403 alice GET /api/admin/users
why "/api/admin/ is admin-only, even for reads (not_rule on the read-only permission)."
row 403 alice POST /api/orders -H 'x-role: admin'
why "Roles must come from the verified token (metadata from jwt_authn: payload_in_metadata), never from a client header."
echo "bob (role admin)"
row 200 bob GET /api/admin/users
row 200 bob POST /api/orders
row 200 bob DELETE /api/orders/1
echo "no token"
row 401 - GET /api/orders
check_ge "Envoy counted RBAC denials (http.ingress.rbac.denied)" 4 "$(stat http.ingress.rbac.denied)"
