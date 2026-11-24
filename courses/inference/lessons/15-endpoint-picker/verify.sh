source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
busy="$(kubectl get pods -l kdrill.dev/role=busy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
busyip="$(pod_ip "$busy")"
E='{.items[0].spec.extProc[0]'
eep="$(kubectl get envoyextensionpolicy -o jsonpath="{range .items[*]}{.spec.extProc[0].backendRefs[0].name}:{.spec.extProc[0].backendRefs[0].port}:{.spec.extProc[0].processingMode.request.body}:{.spec.extProc[0].processingMode.response.body}:{.status.ancestors[0].conditions[?(@.type==\"Accepted\")].status}{\"\n\"}{end}" 2>/dev/null | head -n 1)"
check_eq "EnvoyExtensionPolicy: extProc to Service epp:9002, request and response bodies FullDuplexStreamed, Accepted" "epp:9002:FullDuplexStreamed:FullDuplexStreamed:True" "$eep"
why "The endpoint picker only supports ext_proc body mode FULL_DUPLEX_STREAMED. kubectl explain envoyextensionpolicy.spec.extProc.processingMode"
fo="$(kubectl get envoyextensionpolicy -o jsonpath='{.items[0].spec.extProc[0].failOpen}' 2>/dev/null)"
check "failOpen is not enabled (if the picker is down the request must fail loudly; got: ${fo:-unset})" bash -c '[[ "$1" != true ]]' _ "$fo"
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.spec.loadBalancer.endpointOverride.extractFrom[0].header}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{"\n"}{end}' 2>/dev/null | head -n 1)"
check_eq "BackendTrafficPolicy: endpointOverride reads the picker's answer from header x-gateway-destination-endpoint, Accepted" "x-gateway-destination-endpoint:True" "$btp"
why "The picker answers by setting that header (ip:port); Envoy's override_host load balancer then connects to exactly that pod."
check_eq "The picker is ready and the InferencePool exists" "1 llm" "$(ready_pods app=epp) $(kubectl get inferencepool llm -o jsonpath='{.metadata.name}' 2>/dev/null)"
check "All three replicas are still behind Service llm and the saturated one is Ready: no shortcut (${busy:-?})" \
  bash -c '[[ -n "$1" && "$(kubectl get svc llm -o jsonpath="{.spec.selector.app}")" == llm && "$(kubectl get pod "$1" -o jsonpath="{.metadata.labels.app}")" == llm && "$(kubectl get pod "$1" -o jsonpath="{.status.containerStatuses[0].ready}")" == true ]]' _ "$busy"
U=http://edge/v1/chat/completions
_probe() { epp_active $U; }
(( _KD_FAIL == 0 )) && { gw_wait_config edge dynamic_active_clusters override_host 45 || true; wait_until 30 _probe || true; }   # the endpoint-override cluster needs ~15 s to warm
out="$(ask_out -n 40 -c 4 -t 4 -w 6 $U)"
echo "saturated pod, 40 requests: $(printf '%s' "$out" | tr '\n' ';')"
tot="$(count_of '200 *' "$out")"; b="$(count_of "200 $busy" "$out")"
check_ge "All 40 requests were answered (200) (got $tot)" 40 "$tot"
check "The saturated replica received at most 2 of them (got ${b:-?}; random spreading would give about 13)" bash -c '[[ "$1" -le 2 ]]' _ "${b:-99}"
why "kubectl logs deploy/epp | tail; the picker scores queue depth and KV-cache use per replica and returns the best ip:port."
# the picker is dynamic: when the replica recovers, it gets traffic again
sim_admin "$busyip" '{"fake-metrics":{"running-requests":0,"waiting-requests":0,"kv-cache-usage":0.0}}'
sleep 3
out2="$(ask_out -n 40 -c 4 -t 4 -w 6 $U)"
b2="$(count_of "200 $busy" "$out2")"
check "Once it has recovered (queue 0, cache 0%) it takes its share again (got ${b2:-?} of 40; at least 5)" bash -c '[[ "$1" -ge 5 ]]' _ "${b2:-0}"
why "A fixed exclusion would be a shortcut: the picker must follow the live metrics."
sim_admin "$busyip" '{"fake-metrics":{"running-requests":4,"waiting-requests":40,"kv-cache-usage":0.9}}'   # saturated again for the next verify
