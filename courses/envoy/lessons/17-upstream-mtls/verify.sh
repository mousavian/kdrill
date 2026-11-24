source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "the backend itself (from the client pod, which has no client certificate)"
check_eq "payments refuses a TLS client without a certificate" 000 \
  "$(http_code https://payments/ --cacert /certs/ca.crt --connect-to payments:443:payments:443)"
why "The backend was changed? kdrill reset restores it."

echo "through Envoy"
body="$(http_body http://envoy:10000/pay/42)"
check_eq "GET /pay/42 via Envoy -> answered by payments" "Name: payments" "$(printf '%s\n' "$body" | grep '^Name:' | tr -d '\r')"
why "The cluster needs a transport_socket (envoy.transport_sockets.tls) with an UpstreamTlsContext."
check_eq "... which saw Envoy's client certificate (CN=envoy-client)" "Certificate[0] Subject: CN=envoy-client" \
  "$(printf '%s\n' "$body" | grep '^Certificate\[0\] Subject' | tr -d '\r')"
why "common_tls_context.tls_certificates: /certs/client.crt + /certs/client.key"
check_ge "cluster.payments.ssl.handshake counted TLS handshakes" 1 "$(stat cluster.payments.ssl.handshake)"

echo "Envoy verifies the server (admin /config_dump)"
dump="$(admin '/config_dump?resource=static_clusters' | tr -d ' \n')"
check "validation_context.trusted_ca is /certs/ca.crt" eval '[[ "$dump" == *"\"trusted_ca\":{\"filename\":\"/certs/ca.crt\"}"* ]]'
why "Without a validation_context, Envoy accepts ANY server certificate."
check "match_typed_subject_alt_names checks the DNS name payments.lab.svc.cluster.local" \
  eval '[[ "$dump" == *"\"san_type\":\"DNS\",\"matcher\":{\"exact\":\"payments.lab.svc.cluster.local\"}"* ]]'
check "sni is set to payments.lab.svc.cluster.local" eval '[[ "$dump" == *"\"sni\":\"payments.lab.svc.cluster.local\""* ]]'
