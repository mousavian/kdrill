source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

# who HOST PATH [curl options] -> "STATUS NAME" of one request
who() {
  local h="$1" p="$2"; shift 2
  hits_out -n 1 "http://envoy:10000$p" -H "Host: $h" "$@" | awk '{print $2, $3}'
}
row() { # row EXPECTED HOST PATH [curl options]
  local exp="$1" h="$2" p="$3"; shift 3
  local extra=""; [[ $# -gt 0 ]] && extra=" ($*)"
  check_eq "Host $h, $p$extra -> $exp" "$exp" "$(who "$h" "$p" "$@")"
}

echo "web"
row "200 web" lab /
row "200 web" www.lab /about
row "200 web" blog.lab /posts/1
why "Any other host under .lab goes to web: a suffix wildcard domain \"*.lab\"."
row "404 -" example.com /
why "Hosts outside .lab must not match any virtual host (no \"*\")."
echo "api.lab"
row "200 api-v1" api.lab /users
row "200 api-v2" api.lab /v2
row "200 api-v2" api.lab /v2/users
why "Routes are tried in order and the first match wins: is a prefix \"/\" route listed before the /v2 route?"
row "200 api-v1" api.lab /v2beta/users
why "prefix \"/v2\" also matches /v2beta. path_separated_prefix matches /v2 and /v2/... only."
row "200 api-v2" api.lab /users -H "x-api-version: 2"
row "200 api-v1" api.lab /users -H "x-api-version: 1"
why "match.headers: [{name: x-api-version, string_match: {exact: \"2\"}}] on a route placed before the others."
