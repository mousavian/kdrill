source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
for r in web api; do
  check_eq "HTTPRoute $r is Accepted with ResolvedRefs" "True True" "$(route_cond httproute/$r Accepted) $(route_cond httproute/$r ResolvedRefs)"
done
who() { local h="$1" p="$2"; shift 2; hits_out -n 1 "http://edge$p" -H "Host: $h" "$@" | awk '{print $2, $3}'; }
row() {
  local exp="$1" h="$2" p="$3"; shift 3
  local extra=""; [[ $# -gt 0 ]] && extra=" ($*)"
  check_eq "$h $p$extra -> $exp" "$exp" "$(who "$h" "$p" "$@")"
}
echo "hosts"
row "200 web" www.lab /
row "200 web" blog.lab /posts
why "A wildcard hostname \"*.lab\" on the web route; api.lab still prefers its exact-hostname route."
row "404 -" example.com /
echo "api.lab"
row "200 api-v1" api.lab /users
row "200 api-v2" api.lab /v2
row "200 api-v2" api.lab /v2/users
row "200 api-v1" api.lab /v2beta/users
why "PathPrefix matches whole path segments: /v2 matches /v2 and /v2/..., never /v2beta."
row "200 api-v2" api.lab /users -H "x-api-version: 2"
row "200 api-v2" api.lab "/users?canary=true"
row "200 api-v1" api.lab "/users?canary=false"
row "200 orders" api.lab /orders -X POST
row "200 api-v1" api.lab /orders
why "method: POST on the /orders match; a GET /orders falls back to api-v1."
