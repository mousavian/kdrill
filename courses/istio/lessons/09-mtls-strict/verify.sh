source "$KDRILL_HOME/courses/istio/lib.sh"
settle 2
await_code 10 000 legacy cron http://ledger.bank:8000/get

echo "policy"
check_eq "PeerAuthentication default in bank: STRICT, for the whole namespace (no selector)" "STRICT|" \
  "$(jp peerauthentication/default '{.spec.mtls.mode}|{.spec.selector}' -n bank)"
why "A PeerAuthentication without selector applies to every workload in its namespace; name it default by convention."
check_eq "No mesh-wide PeerAuthentication in istio-system (keep it to bank)" "" \
  "$(kubectl -n istio-system get peerauthentication -o name 2>/dev/null)"

echo "in the mesh (shop/web -> bank/ledger)"
hdrs="$(http_body shop web http://ledger.bank:8000/headers)"
check "web reaches ledger:8000 over mTLS (ledger sees spiffe://cluster.local/ns/shop/sa/web)" \
  grep -q 'URI=spiffe://cluster.local/ns/shop/sa/web' <<<"$hdrs"
check_eq "web reaches ledger's metrics port 9090" 200 "$(http_code shop web http://ledger.bank:9090/get)"

echo "outside the mesh (legacy/cron, plaintext)"
check_eq "cron -> ledger:8000 is rejected (no HTTP answer: connection reset)" 000 "$(http_code legacy cron http://ledger.bank:8000/get)"
why "PERMISSIVE accepts plaintext; STRICT accepts only mTLS. kubectl -n bank get peerauthentication"
check_eq "cron -> ledger:9090 (metrics) still works" 200 "$(http_code legacy cron http://ledger.bank:9090/get)"
why "Use a second PeerAuthentication with selector app: ledger and portLevelMtls for the container port 9090: PERMISSIVE."
