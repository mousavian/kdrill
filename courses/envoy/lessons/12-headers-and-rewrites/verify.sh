source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "what the backend receives (the echo app prints the request it got)"
body="$(http_body http://envoy:10000/api/v1/users?page=2 -H 'x-env: prod' -H 'x-debug-token: s3cr3t' -H 'x-request-id: kdrill-12')"
line="$(printf '%s\n' "$body" | grep -E '^(GET|POST) ' | tr -d '\r')"
check_eq "GET /api/v1/users?page=2 arrives as GET /v1/users?page=2" "GET /v1/users?page=2 HTTP/1.1" "$line"
why "route.prefix_rewrite replaces the matched prefix (/api/) with the given one (/)."
check_eq "Host header is api.internal" "Host: api.internal" "$(printf '%s\n' "$body" | grep '^Host:' | tr -d '\r')"
check_eq "x-env is exactly lab, even when the client sent x-env: prod" "X-Env: lab" "$(printf '%s\n' "$body" | grep -i '^x-env:' | tr -d '\r' | paste -sd'|' -)"
why "request_headers_to_add with append_action OVERWRITE_IF_EXISTS_OR_ADD (the default appends a second value)."
check "x-debug-token from the client is removed" eval '! printf "%s\n" "$body" | grep -qi "^x-debug-token:"'
check_eq "x-request-id passes through unchanged" "X-Request-Id: kdrill-12" "$(printf '%s\n' "$body" | grep -i '^x-request-id:' | tr -d '\r')"
echo "what the client receives"
check_eq "Response header x-served-by: envoy-lab" envoy-lab "$(http_head http://envoy:10000/api/v1/users x-served-by)"
check_eq "Paths outside /api/ still get 404" 404 "$(http_code http://envoy:10000/v1/users)"
