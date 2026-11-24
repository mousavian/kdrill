source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "Gateway edge is programmed" True "$(gw_cond edge Programmed)"
for l in https-shop https-api; do
  check_eq "Listener $l exists with resolved certificate refs" True "$(jp gateway/edge "{.status.listeners[?(@.name==\"$l\")].conditions[?(@.type==\"ResolvedRefs\")].status}")"
done
# tls HOST [curl options] -> "STATUS VERSION|SUBJECT|NAME" for https://HOST/ via the Service edge:443
tls() {
  local h="$1"; shift
  kx sh -c "rm -f /tmp/b /tmp/e; curl -sv $* --connect-timeout 2 --max-time 4 --cacert /certs/ca.crt --connect-to $h:443:edge:443 -o /tmp/b -w '%{http_code} %{http_version}' https://$h/products 2>/tmp/e; printf '|'; sed -n 's/^\\* *subject: *//p' /tmp/e | head -n 1 | tr -d '\\r\\n'; printf '|'; sed -n 's/^Name: //p' /tmp/b | tr -d '\\r\\n'"
}
echo "HTTPS (client trusts only the lab CA)"
for s in shop api; do
  r="$(tls $s.lab)"
  check_eq "https://$s.lab/ -> 200 from $s with certificate CN=$s.lab" "200|CN=$s.lab|$s" "$(echo "$r" | cut -d' ' -f1)|$(echo "$r" | cut -d'|' -f2 | tr -d ' ')|$(echo "$r" | cut -d'|' -f3)"
  why "An HTTPS listener (port 443, hostname $s.lab, tls.certificateRefs $s-tls) and the HTTPRoute attached to it."
done
check_eq "HTTP/2 is negotiated" "200 2" "$(tls shop.lab --http2 | cut -d'|' -f1)"
r="$(tls shop.lab --tlsv1.2 --tls-max 1.2)"
check_eq "A client limited to TLS 1.2 is refused" 000 "$(echo "$r" | cut -d' ' -f1)"
why "ClientTrafficPolicy targeting the Gateway: tls.minVersion \"1.3\""
ctp="$(kubectl get clienttrafficpolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A ClientTrafficPolicy targets Gateway edge and is Accepted (got: ${ctp:-none})" eval '[[ "$ctp" == *"Gateway/edge:True"* ]]'
echo "plain HTTP"
check_eq "http://shop.lab/products?id=1 -> 301 to https://shop.lab/products?id=1" "https://shop.lab/products?id=1" \
  "$(http_head 'http://edge/products?id=1' location -H 'Host: shop.lab')"
check_eq "http://api.lab/x -> 301" 301 "$(http_code http://edge/x -H 'Host: api.lab')"
why "An HTTPRoute attached only to the http listener (parentRefs sectionName: http) with a RequestRedirect to scheme https."
check_eq "No plain-HTTP access to the shop backend any more" "" "$(http_body http://edge/ -H 'Host: shop.lab' | grep '^Name:')"
