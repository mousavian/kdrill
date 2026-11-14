source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "Gateway edge is Programmed" True "$(gw_cond edge Programmed)"
mode="$(jp gateway/edge '{.spec.listeners[?(@.port==443)].protocol}/{.spec.listeners[?(@.port==443)].tls.mode}')"
check_eq "A listener on port 443 with protocol TLS and mode Passthrough" "TLS/Passthrough" "$mode"
check "No certificate on the Gateway (passthrough)" test -z "$(jp gateway/edge '{.spec.listeners[*].tls.certificateRefs}')"
for r in site-a site-b; do
  check_eq "TLSRoute $r: Accepted and ResolvedRefs" "True True" "$(route_cond tlsroute/$r Accepted) $(route_cond tlsroute/$r ResolvedRefs)"
done
why "kubectl get tlsroute -o yaml: an HTTP listener doesn't accept TLSRoutes (NotAllowedByListeners)."
tls() {
  local h="$1"; shift
  kx sh -c "rm -f /tmp/b /tmp/e; curl -sv $* --connect-timeout 2 --max-time 4 --cacert /certs/ca.crt --connect-to $h:443:edge:443 -o /tmp/b -w '%{http_code}' https://$h/hello 2>/tmp/e; printf '|'; sed -n 's/^\\* *subject: *//p' /tmp/e | head -n 1 | tr -d '\\r\\n'; printf '|'; sed -n 's/^Name: //p' /tmp/b | tr -d '\\r\\n'"
}
echo "TLS through the Gateway (client trusts only the lab CA)"
for s in a b; do
  check_eq "https://$s.lab -> 200 from site-$s with site-$s's own certificate CN=$s.lab" "200|CN=$s.lab|site-$s" "$(tls $s.lab | tr -d ' ')"
done
check_eq "An unknown SNI (c.lab) is refused, even for a client that accepts any certificate" 000 "$(tls c.lab --insecure | cut -d'|' -f1)"
