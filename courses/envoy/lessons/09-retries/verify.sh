source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
three() { [[ "$(cluster_hosts echo | wc -w | tr -d ' ')" == 3 ]]; }
wait_until 10 three || true
check_eq "Cluster echo has 3 hosts (2 echo pods + the sick pod)" 3 "$(cluster_hosts echo | wc -w | tr -d ' ')"
why "Keep the sick pod in the Service and the cluster: retries should cope with it."
sick_ip="$(pod_ips app=sick)"
sick_rq() { admin /clusters | awk -F'::' -v h="$sick_ip:80" '$1=="echo" && $2==h && $3=="rq_total" {print $4}'; }

echo "configuration"
routes="$(admin '/config_dump?resource=static_route_configs')"
clusters="$(admin '/config_dump?resource=static_clusters')"
check "Retries pick a different host (retry_host_predicate previous_hosts)" eval 'printf "%s" "$routes" | grep -q previous_hosts'
nr="$(printf '%s' "$routes" | grep -o '"num_retries": [0-9]*' | grep -o '[0-9]*$' | sort -n | tail -n 1)"
check "At most 2 retries (num_retries: ${nr:-<unset, default 1>})" test "${nr:-1}" -le 2
check "No outlier detection or health checks (retries alone must do it)" \
  eval '! printf "%s" "$clusters" | grep -qE "\"(outlier_detection|health_checks)\""'

echo "GET (60 requests)"
r0="$(stat cluster.echo.upstream_rq_retry)"; s0="$(sick_rq)"
out="$(hits_out -n 60 http://envoy:10000/items)"
r1="$(stat cluster.echo.upstream_rq_retry)"; s1="$(sick_rq)"
check_eq "All 60 GETs answered 200" 60 "$(count_of "200 *" "$out")"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -). retry_policy: {retry_on: \"5xx\", num_retries: 2} on the route."
check_ge "Envoy retried (cluster.echo.upstream_rq_retry +$((r1 - r0)))" 5 $((r1 - r0))
check_ge "The sick pod still received requests (it is retried around, not removed)" 5 $(( ${s1:-0} - ${s0:-0} ))

echo "POST (30 requests): never retried"
r0="$(stat cluster.echo.upstream_rq_retry)"
out="$(hits_out -n 30 http://envoy:10000/orders -X POST -d '{"item":1}')"
r1="$(stat cluster.echo.upstream_rq_retry)"
check_eq "No retries for POST (upstream_rq_retry +$((r1 - r0)))" 0 $((r1 - r0))
why "Envoy retries any method. Put the retry_policy on a route that matches only GET (header \":method\"), and a route without retries for the rest."
check_ge "So some POSTs fail with the sick pod's 503 ($(count_of "503 *" "$out") of 30)" 3 "$(count_of "503 *" "$out")"
check_ge "... and the others still succeed" 10 "$(count_of "200 *" "$out")"
