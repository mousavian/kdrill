source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
U=http://envoy:10000
# res PATH HOST -> "STATUS|LOCATION|BODY-FIRST-LINE"
res() {
  kx sh -c "curl -s -D /tmp/h -o /tmp/b -w '%{http_code}' -H 'Host: $2' '$U$1'; printf '|'; grep -i '^location:' /tmp/h | cut -d' ' -f2- | tr -d '\r\n'; printf '|'; head -n 1 /tmp/b | tr -d '\r'"
}
echo "/healthz (answered by Envoy, on every host)"
w0="$(stat cluster.web.upstream_rq_total)"
for h in new.lab old.lab whatever.example; do
  check_eq "Host $h: GET /healthz -> 200 ok" "200||ok" "$(res /healthz $h)"
done
w1="$(stat cluster.web.upstream_rq_total)"
check_eq "... without involving the backend (cluster.web.upstream_rq_total unchanged)" "$w0" "$w1"
why "direct_response: {status: 200, body: {inline_string: \"ok\\n\"}} in a route matching path /healthz, in every virtual host."
echo "old.lab"
check_eq "old.lab/products/7?x=1 -> 301 to https://new.lab/products/7?x=1" "301|https://new.lab/products/7?x=1" "$(res '/products/7?x=1' old.lab | cut -d'|' -f1,2)"
why "redirect: {scheme_redirect: https, host_redirect: new.lab, response_code: MOVED_PERMANENTLY}"
echo "new.lab"
check_eq "new.lab/blog/2024/hello -> 308 to /news/2024/hello" "308|http://new.lab/news/2024/hello" "$(res /blog/2024/hello new.lab | cut -d'|' -f1,2)"
why "redirect: {prefix_rewrite: \"/news/\", response_code: PERMANENT_REDIRECT} on a route matching prefix /blog/"
check_eq "new.lab/shop -> 200 from the web backend" "200|Name: web" "$(res /shop new.lab | cut -d'|' -f1,3)"
echo "unknown sites"
check_eq "Host whatever.example, /shop -> 404 with body 'no such site'" "404||no such site" "$(res /shop whatever.example)"
