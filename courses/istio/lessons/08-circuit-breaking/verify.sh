source "$KDRILL_HOME/courses/istio/lib.sh"
NS=bank
U=http://ledger:8000
settle 2

echo "setup unchanged"
check_eq "Both ledger Pods are still running and Ready (stable, canary)" "1 1" \
  "$(jp deploy/ledger '{.status.readyReplicas}' -n $NS) $(jp deploy/ledger-canary '{.status.readyReplicas}' -n $NS)"
why "Don't delete or fix the canary: the mesh must cope with it. kdrill reset restores it."
check_eq "VirtualService ledger still has retries switched off" 0 "$(jp virtualservice/ledger '{.spec.http[0].retries.attempts}' -n $NS)"

echo "outlier detection"
c="$(codes $NS teller $U/get 30)"
ok="$(count_of 200 "$c")"
check "At least 27 of 30 sequential requests succeed (got ${c:-no answers})" between 27 30 "$ok"
why "The canary answers every request with 503. outlierDetection (consecutive5xxErrors <= 3) ejects it after a few errors."

echo "circuit breaker (10 concurrent requests that each take 1 s)"
res="$(in_client $NS teller curl -s -Z --parallel-immediate --parallel-max 10 -m 8 \
        -w '%{http_code}:%header{x-envoy-overloaded}\n' $(for i in 1 2 3 4 5 6 7 8 9 10; do printf -- '-o /dev/null %s ' "$U/delay/1"; done))"
over="$(grep -c '^503:true' <<<"$res")"; okc="$(grep -c '^200:' <<<"$res")"
echo "    (results: $(sort <<<"$res" | uniq -c | awk '{print $2"x"$1}' | paste -sd' ' -))"
check "At least 5 of 10 are rejected at once with 503 + x-envoy-overloaded: true (got $over)" between 5 10 "$over"
why "connectionPool: tcp.maxConnections: 1 and http.http1MaxPendingRequests: 1. Excess requests overflow immediately."
check "At least one still succeeds (got $okc)" between 1 10 "$okc"
