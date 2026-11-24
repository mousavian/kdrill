source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "a burst: 20 requests at once, each takes 2 s (?wait=2s)"
o0="$(stat cluster.reports.upstream_rq_pending_overflow)"
out="$(hits_out -n 20 -c 20 -r x-envoy-overloaded 'http://envoy:10000/reports/q?wait=2s')"
o1="$(stat cluster.reports.upstream_rq_pending_overflow)"
ok="$(count_of "200 *" "$out")"; over="$(count_of "503 true" "$out")"
why_out="got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -)"
check "Between 4 and 8 of them were served (4 at a time + 2 waiting; got $ok)" test "$ok" -ge 4 -a "$ok" -le 8
why "$why_out. circuit_breakers.thresholds on the cluster: max_connections 4, max_pending_requests 2, max_requests 4."
check_ge "The rest were rejected at once: 503 with x-envoy-overloaded: true" 12 "$over"
why "$why_out"
check_ge "Envoy counted the overflow (cluster.reports.upstream_rq_pending_overflow +$((o1 - o0)))" 12 $((o1 - o0))

echo "normal traffic"
out="$(hits_out -n 10 'http://envoy:10000/reports/q')"
check_eq "10 sequential requests: all 200" 10 "$(count_of "200 *" "$out")"
mx="$(admin /clusters | awk -F'::' '$1=="reports" && $2=="default_priority" && $3=="max_connections" {print $4}')"
check_eq "/clusters reports the limit: default_priority::max_connections::4" 4 "$mx"
