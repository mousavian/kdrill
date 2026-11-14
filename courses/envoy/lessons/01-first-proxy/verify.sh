source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "configuration (admin interface, http://envoy:9901)"
hosts="$(cluster_hosts echo)"
check "Envoy has a cluster echo with at least one host on port 80" test -n "$hosts" -a "${hosts##*:}" = 80
why "admin /clusters lists every cluster and host: kubectl exec client -- curl -s envoy:9901/clusters"

echo "behaviour (20 requests from the client pod to http://envoy:10000/)"
before="$(stat cluster.echo.upstream_rq_200)"
out="$(hits_out -n 20 http://envoy:10000/)"
check_eq "All 20 requests answered 200 by the echo backend" 20 "$(count_of "200 echo" "$out")"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -)"
after="$(stat cluster.echo.upstream_rq_200)"
check_ge "Envoy counted them as upstream requests of cluster echo (cluster.echo.upstream_rq_200)" $((before + 20)) "$after"
body="$(http_body http://envoy:10000/hello)"
check "The backend saw the request through Envoy's router (X-Envoy-Expected-Rq-Timeout-Ms, path /hello)" \
  eval '[[ "$body" == *"GET /hello HTTP/1.1"* && "$body" == *"X-Envoy-Expected-Rq-Timeout-Ms"* ]]'
