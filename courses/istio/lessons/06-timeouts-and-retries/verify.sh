source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
U=http://inventory:8000
marker="kdrill-$RANDOM$RANDOM"
settle 2

echo "timeout"
read -r code t <<<"$(IST_TIMEOUT=8 http_time $NS web $U/delay/5)"
check_eq "A 5 s request is cut off with 504 by the mesh (took ${t}s)" 504 "$code"
check "... after about 2 seconds (less than 3 s)" faster_than 3 "$t"
why "VirtualService http[].timeout bounds the whole request. Envoy answers 504 'upstream request timeout'."
read -r code t <<<"$(http_time $NS web $U/delay/1)"
check_eq "A 1 s request still succeeds (200, took ${t}s)" 200 "$code"
why "Don't make the timeout (or perTryTimeout) shorter than legitimate requests."

echo "retries"
c="$(codes $NS web "$U/unstable?failure_rate=0.4" 50)"
ok="$(count_of 200 "$c")"
check "Flaky endpoint (fails 40% of the time): at least 45 of 50 requests succeed (got ${ok}; ${c:-no answers})" between 45 50 "$ok"
why "Istio's default retry policy only retries connection errors and 503. retryOn must include 5xx for a 500."
http_code $NS web "$U/status/500?probe=$marker" >/dev/null
sleep 1
n="$(kubectl -n $NS logs deploy/inventory -c inventory --since=2m 2>/dev/null | grep -c "$marker")"
check_eq "A request that always fails reaches inventory 4 times (1 try + 3 retries)" 4 "$n"
why "retries.attempts is the number of RETRIES, on top of the first try."
check_eq "The retry policy is in VirtualService inventory, route main" main "$(jp virtualservice/inventory '{.spec.http[?(@.retries)].name}' -n $NS)"
