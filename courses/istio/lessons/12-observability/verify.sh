source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
m="kdrill-$RANDOM$RANDOM"
settle 2

echo "sending test traffic web -> catalog (marker $m)"
codes $NS web "http://catalog:8000/status/200?probe=$m-ok" 5 -H 'x-tenant: acme' >/dev/null
codes $NS web "http://catalog:8000/status/503?probe=$m-err" 3 -H 'x-tenant: acme' >/dev/null
codes $NS web "http://catalog:8000/status/404?probe=$m-nf" 2 -H 'x-tenant: globex' >/dev/null
sleep 3
srv="$(kubectl -n $NS logs deploy/catalog -c istio-proxy --since=3m 2>/dev/null)"
cli="$(kubectl -n $NS logs deploy/web -c istio-proxy --since=3m 2>/dev/null)"

echo "access logs"
check_eq "catalog's sidecar logged the 3 failed requests (503)" 3 "$(grep -c "$m-err" <<<"$srv")"
why "Telemetry accessLogging with provider envoy; check: kubectl -n shop logs deploy/catalog -c istio-proxy"
check_eq "catalog's sidecar logged the 2 not-found requests (404)" 2 "$(grep -c "$m-nf" <<<"$srv")"
check_eq "catalog's sidecar did NOT log the 5 successful requests" 0 "$(grep -c "$m-ok" <<<"$srv")"
why "accessLogging[].filter.expression: response.code >= 400"
check_ge "web's sidecar logs failures too (the policy covers the whole namespace)" 3 "$(grep -c "$m-err" <<<"$cli")"
why "A Telemetry without selector applies to every workload in its namespace."

echo "metrics (catalog's Envoy, /stats/prometheus)"
prom="$(proxy_admin $NS catalog stats/prometheus | grep '^istio_requests_total{' | grep 'reporter="destination"')"
check "istio_requests_total has tenant=\"acme\" for the 503s" grep -q 'response_code="503".*tenant="acme"' <<<"$prom"
check "istio_requests_total has tenant=\"globex\" for the 404s" grep -q 'response_code="404".*tenant="globex"' <<<"$prom"
why "Telemetry metrics overrides: match metric REQUEST_COUNT (mode SERVER), tagOverrides tenant: {value: request.headers['x-tenant']}"
