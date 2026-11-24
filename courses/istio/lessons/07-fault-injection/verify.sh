source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
U=http://ratings:8000/get
settle 2

echo "x-chaos: abort"
check_eq "5 of 5 requests get 503" "503:5" "$(codes $NS web $U 5 -H 'x-chaos: abort')"
check "The 503 comes from Envoy's fault filter, not from ratings" \
  grep -q 'fault filter abort' <<<"$(http_body $NS web $U -H 'x-chaos: abort')"
why "fault.abort.httpStatus: 503 with percentage 100 on a route that matches x-chaos: abort."

echo "x-chaos: delay"
read -r code t <<<"$(IST_TIMEOUT=8 http_time $NS web $U -H 'x-chaos: delay')"
check_eq "Delayed request still succeeds" 200 "$code"
check "... after about 2 s (1.9-3.5 s; took ${t}s)" awk -v t="$t" 'BEGIN{exit !(t >= 1.9 && t <= 3.5)}'
why "fault.delay.fixedDelay: 2s, percentage 100."

echo "x-chaos: flaky"
c="$(codes $NS web $U 100 -H 'x-chaos: flaky')"
f="$(count_of 500 "$c")"; ok="$(count_of 200 "$c")"
check "About half of 100 requests fail with 500 (30-70; got ${c:-no answers})" between 30 70 "$f"
check_eq "... and the others succeed" 100 "$((f + ok))"
why "fault.abort.httpStatus: 500 with percentage: {value: 50}."

echo "everyone else"
c="$(codes $NS web $U 20)"
check_eq "20 normal requests all succeed" "200:20" "$c"
read -r code t <<<"$(http_time $NS web $U -H 'x-chaos: none')"
check "A request with another x-chaos value is not delayed or aborted (got $code in ${t}s)" \
  awk -v c="$code" -v t="$t" 'BEGIN{exit !(c == 200 && t < 1)}'
why "Scope each fault to its own match; keep a catch-all route without a fault last."
