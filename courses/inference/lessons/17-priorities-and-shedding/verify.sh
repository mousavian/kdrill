source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
U=http://edge/v1/chat/completions
pr() { jp inferenceobjective/$1 '{.spec.priority}'; }
cp="$(pr chat)"; bp="$(pr batch)"
check "InferenceObjective chat exists with a priority of 0 or more (got ${cp:-none})" bash -c '[[ "$1" =~ ^[0-9]+$ ]]' _ "${cp:-x}"
check "InferenceObjective batch exists with a negative priority (got ${bp:-none})" bash -c '[[ "$1" =~ ^-[0-9]+$ ]]' _ "${bp:-x}"
why "kubectl explain inferenceobjective.spec.priority: negative = sheddable (dropped first when the pool is saturated)."
check "... and both apply to the pool (poolRefs: pool)" bash -c '[[ "$(kubectl get inferenceobjective chat -o jsonpath="{.spec.poolRefs[0].name}")" == pool && "$(kubectl get inferenceobjective batch -o jsonpath="{.spec.poolRefs[0].name}")" == pool ]]'
_probe() { epp_active $U; }
(( _KD_FAIL == 0 )) && { gw_wait_config edge dynamic_active_clusters override_host 45 || true; wait_until 30 _probe || true; }   # the endpoint-override cluster needs ~15 s to warm
sleep 2
c="$(ask_out -n 8 -c 4 -t 4 -w 6 -H 'x-gateway-inference-objective: chat' $U)"
b="$(ask_out -n 8 -c 4 -t 4 -w 6 -H 'x-gateway-inference-objective: batch' $U)"
echo "saturated pool: chat: $(printf '%s' "$c" | tr '\n' ';') batch: $(printf '%s' "$b" | tr '\n' ';')"
check_eq "Saturated pool: 8 of 8 requests marked chat are served (200)" 8 "$(count_matching '^200 ' "$c")"
check_eq "Saturated pool: 8 of 8 requests marked batch are shed with 429" 8 "$(count_matching '^429 ' "$b")"
why "kubectl logs deploy/epp | grep -i sheddable; the picker only sheds when EVERY replica is saturated (queue deep or KV cache full)."
# shedding is a response to saturation, not a ban: when the pool recovers, batch is served again
for ip in $(pod_ips app=pool); do sim_admin "$ip" '{"fake-metrics":{"running-requests":0,"waiting-requests":0,"kv-cache-usage":0.1}}'; done
sleep 2
r="$(ask_out -n 6 -c 3 -t 4 -w 6 -H 'x-gateway-inference-objective: batch' $U)"
check_eq "Once the pool has recovered, batch requests are served again (6 of 6)" 6 "$(count_matching '^200 ' "$r")"
for ip in $(pod_ips app=pool); do sim_admin "$ip" '{"fake-metrics":{"running-requests":2,"waiting-requests":30,"kv-cache-usage":0.95}}'; done   # saturated again for the next verify
