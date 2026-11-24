source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
# tls HOST [curl options] -> "STATUS HTTPVERSION|SUBJECT|NAME"  (TLS to envoy:10443 with SNI HOST)
tls() {
  local h="$1"; shift
  kx sh -c "rm -f /tmp/b /tmp/e; curl -sv --max-time 5 --cacert /certs/ca.crt --connect-to $h:10443:envoy:10443 -o /tmp/b -w '%{http_code} %{http_version}' $* https://$h:10443/products 2>/tmp/e; printf '|'; sed -n 's/^\\* *subject: *//p' /tmp/e | head -n 1 | tr -d '\\r\\n'; printf '|'; sed -n 's/^Name: //p' /tmp/b | tr -d '\\r\\n'"
}
echo "HTTPS on 10443 (curl trusts only the lab CA, /certs/ca.crt in the client pod)"
for h in shop api; do
  r="$(tls $h.lab)"
  check_eq "https://$h.lab:10443/ -> 200 from $h" "200|$h" "$(echo "$r" | cut -d'|' -f1 | cut -d' ' -f1)|$(echo "$r" | cut -d'|' -f3)"
  why "A listener on 10443 with a filter chain per server name (filter_chain_match.server_names) and a DownstreamTlsContext."
  check_eq "... with the $h.lab certificate (chosen by SNI)" "CN=$h.lab" "$(echo "$r" | cut -d'|' -f2 | tr -d ' ')"
  why "Each filter chain's tls_certificates: /certs/$h.crt and /certs/$h.key."
done
r="$(tls shop.lab --http2)"
check_eq "HTTP/2 is negotiated with ALPN (curl --http2)" "200 2" "$(echo "$r" | cut -d'|' -f1)"
why "common_tls_context.alpn_protocols: [h2, http/1.1]"
r="$(tls other.lab --insecure)"
check_eq "An unknown SNI (other.lab) gets no TLS session" 000 "$(echo "$r" | cut -d'|' -f1 | cut -d' ' -f1)"
why "No filter chain without server_names: connections that match no chain are closed."
echo "plain HTTP on 10000"
loc="$(http_head http://envoy:10000/products?id=1 location -H 'Host: shop.lab')"
check_eq "http://shop.lab/products?id=1 -> redirect to https://shop.lab/products?id=1" "https://shop.lab/products?id=1" "$loc"
why "redirect: {https_redirect: true} on the plain listener"
check_eq "... with status 301" 301 "$(http_code http://envoy:10000/x -H 'Host: api.lab')"
