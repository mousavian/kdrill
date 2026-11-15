source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
slow="$(kubectl get pods -l kdrill.dev/role=slow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[*].kind}/{.spec.targetRefs[*].name}:{.spec.loadBalancer.type}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{end}' 2>/dev/null)"
check "A BackendTrafficPolicy on HTTPRoute llm uses loadBalancer type LeastRequest and is Accepted (got: ${btp:-none})" bash -c '[[ "$1" == *"HTTPRoute/llm:LeastRequest:True"* ]]' _ "$btp"
why "kubectl explain backendtrafficpolicy.spec.loadBalancer.type (RoundRobin, Random, LeastRequest, ConsistentHash)"
check "The slow pod is still ready and still behind the Service (it must receive less traffic, not be removed): ${slow:-?}" bash -c '[[ -n "$1" ]] && [[ "$(kubectl get pod "$1" -o jsonpath="{.status.containerStatuses[0].ready}")" == true ]] && [[ "$(kubectl get pod "$1" -o jsonpath="{.metadata.labels.app}")" == llm ]] \
  && [[ "$(kubectl get svc llm -o jsonpath="{.spec.selector.app}")" == llm ]]' _ "$slow"
check_eq "Three replicas are ready" 3 "$(ready_pods app=llm)"
if [[ "$btp" == *":True"* ]]; then gw_wait_config edge dynamic_active_clusters least_request 25 || true; fi
U=http://edge/v1/chat/completions
out="$(ask_out -n 120 -c 12 -t 6 -w 10 -r x-inference-pod $U)"
# ask prints "N STATUS WHO": count requests answered by the slow pod and in total
total="$(count_of '200 *' "$out")"; slowc="$(count_of "200 ${slow:-none}" "$out")"
echo "load: 120 requests from 12 users: $(printf '%s' "$out" | tr '\n' ';')"
check_ge "All 120 requests were answered (200) (got $total)" 120 "$total"
check "The slow replica served at most 20% of them (${slowc:-0} of ${total:-0}; round-robin gives about a third)" bash -c '[[ "${2:-0}" -gt 0 ]] && (( $1 * 5 <= $2 ))' _ "${slowc:-99}" "${total:-0}"
why "Round-robin ignores how busy a backend is; least-request sends the next request to the backend with fewer requests in flight, and the slow one always has more."
