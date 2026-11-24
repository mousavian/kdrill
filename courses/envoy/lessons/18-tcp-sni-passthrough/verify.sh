source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
# tls HOST [curl options] -> "STATUS|SUBJECT|NAME"  (TLS to envoy:10443 with SNI HOST, trusting only the lab CA)
tls() {
  local h="$1"; shift
  kx sh -c "rm -f /tmp/b /tmp/e; curl -sv $* --max-time 5 --cacert /certs/ca.crt --connect-to $h:10443:envoy:10443 -o /tmp/b -w '%{http_code}' https://$h:10443/hello 2>/tmp/e; printf '|'; sed -n 's/^\\* *subject: *//p' /tmp/e | head -n 1 | tr -d '\\r\\n'; printf '|'; sed -n 's/^Name: //p' /tmp/b | tr -d '\\r\\n'"
}
echo "TLS through Envoy on 10443"
for s in a b; do
  check_eq "https://$s.lab:10443/ -> 200 from site-$s, with site-$s's own certificate CN=$s.lab" "200|CN=$s.lab|site-$s" "$(tls $s.lab | tr -d ' ')"
  why "One filter chain per SNI (filter_chain_match.server_names, read by the tls_inspector listener filter), each with a tcp_proxy to its cluster."
done
check_eq "An unknown SNI (c.lab) is refused, even for a client that accepts any certificate" 000 "$(tls c.lab --insecure | cut -d'|' -f1)"
why "Don't keep a filter chain without filter_chain_match: it would catch every other name."
echo "passthrough, not termination (admin /config_dump)"
dump="$(admin '/config_dump?resource=static_listeners')"
check "No listener terminates TLS (no DownstreamTlsContext)" eval '! printf "%s" "$dump" | grep -q DownstreamTlsContext'
check "The TCP proxy carries the connections (envoy.filters.network.tcp_proxy, no HCM)" \
  eval 'printf "%s" "$dump" | grep -q TcpProxy && ! printf "%s" "$dump" | grep -q HttpConnectionManager'
