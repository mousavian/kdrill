source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
ref="$(jp gateway/edge '{.spec.infrastructure.parametersRef.kind}/{.spec.infrastructure.parametersRef.name}')"
check "Gateway edge references an EnvoyProxy (infrastructure.parametersRef; got: $ref)" eval '[[ "$ref" == EnvoyProxy/?* ]] && kubectl get envoyproxy "${ref#EnvoyProxy/}"'
check_eq "Gateway edge is Programmed" True "$(gw_cond edge Programmed)"
why "kubectl describe gateway edge. A Gateway-level EnvoyProxy replaces the cluster defaults (ClusterIP Service!) unless it sets mergeType: StrategicMerge."
check_eq "Its Service is still ClusterIP" ClusterIP "$(jp svc/edge '{.spec.type}')"
echo "the Envoy pods"
pod="$(gw_pod edge)"
check_eq "Envoy pod carries the label team=platform" platform "$(jp pod/$pod '{.metadata.labels.team}')"
why "provider.kubernetes.envoyDeployment.pod.labels"
check_eq "Envoy container requests 40Mi memory" 40Mi "$(jp pod/$pod '{.spec.containers[?(@.name=="envoy")].resources.requests.memory}')"
why "provider.kubernetes.envoyDeployment.container.resources.requests"
echo "access log"
rid="kdrill-$RANDOM$RANDOM"
# (Envoy Gateway replaces the x-request-id of external clients, so mark the path instead)
http_code "http://edge/products?id=7&run=$rid" -H 'Host: www.lab' >/dev/null
line() { kubectl logs "pod/$pod" -c envoy --since=60s 2>/dev/null | grep -F "$rid" | tail -n 1; }
seen() { [[ -n "$(line)" ]]; }
wait_until 13 seen   # file access logs are flushed every 10 s
l="$(line)"
keys="$(printf '%s' "$l" | grep -o '"[a-z_:-]*":' | tr -d '":' | sort | paste -sd' ' -)"
check_eq "The log line has exactly the platform's keys" "duration_ms flags method path request_id status upstream" "$keys"
why "telemetry.accessLog.settings: [{format: {type: JSON, json: {...}}, sinks: [{type: File, file: {path: /dev/stdout}}]}]"
check "... with status 200 and the path with its query (/products?id=7&run=...)" eval '[[ "$l" == *"\"status\":200"* && "$l" == *"\"path\":\"/products?id=7&run=$rid\""* ]]'
