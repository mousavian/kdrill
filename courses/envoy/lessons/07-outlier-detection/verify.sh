source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
three() { [[ "$(cluster_hosts echo | wc -w | tr -d ' ')" == 3 ]]; }
wait_until 10 three || true
check_eq "Cluster echo has 3 hosts (2 echo pods + the sick pod)" 3 "$(cluster_hosts echo | wc -w | tr -d ' ')"
why "Don't remove the sick pod from the Service or the cluster: Envoy should handle it."
sick_ip="$(pod_ips app=sick)"

dump="$(admin '/config_dump?resource=static_clusters')"
echo "configuration (admin /config_dump)"
c5="$(printf '%s' "$dump" | grep -o '"consecutive_5xx": [0-9]*' | head -n 1 | grep -o '[0-9]*$')"
check_eq "outlier_detection.consecutive_5xx is 3" 3 "$c5"
bet="$(printf '%s' "$dump" | sed -n 's/.*"base_ejection_time": "\([0-9.]*\)s".*/\1/p' | head -n 1)"
check "base_ejection_time is at least 30s (got ${bet:-default 30}s)" awk -v b="${bet:-30}" 'BEGIN{exit !(b>=30)}'
check "No active health check and no retries (this lesson is about passive detection)" \
  eval '! printf "%s" "$dump" | grep -q "\"health_checks\"" && ! admin "/config_dump?resource=static_route_configs" | grep -q retry_policy'

echo "behaviour"
warm="$(hits_out -n 15 http://envoy:10000/)"
ejected() { [[ "$(host_flags echo "$sick_ip:80")" == *failed_outlier_check* ]]; }
wait_until 5 ejected || true
check "After 15 warm-up requests ($(count_of "503 *" "$warm") failed), the sick pod is ejected (/failed_outlier_check)" ejected
why "admin /clusters | grep health_flags; stat cluster.echo.outlier_detection.ejections_active"
check_ge "Envoy counted an enforced consecutive-5xx ejection" 1 "$(stat cluster.echo.outlier_detection.ejections_enforced_consecutive_5xx)"
# Workers apply host health changes after a short merge window (update_merge_window, 1 s).
clean() { [[ "$(count_of "200 *" "$(hits_out -n 6 http://envoy:10000/)")" == 6 ]]; }
ejected && wait_until 6 clean
out="$(hits_out -p -n 30 http://envoy:10000/)"
check_eq "The next 30 requests: all 200" 30 "$(count_of "200 *" "$out")"
check_eq "... spread over both healthy echo pods" 2 "$(whos "$out" | wc -w | tr -d ' ')"
