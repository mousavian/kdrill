source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
U=http://edge/v1/chat/completions
C='{.spec.template.spec.containers[0]'
S='{.spec'
echo "routing"
check_eq "HTTPRoute summarize: accepted, references resolved" "True True" "$(route_cond httproute/summarize Accepted) $(route_cond httproute/summarize ResolvedRefs)"
why "kubectl describe httproute summarize: the ResolvedRefs condition names the backend it could not find."
check_eq "HTTPRoute chat: accepted, references resolved" "True True" "$(route_cond httproute/chat Accepted) $(route_cond httproute/chat ResolvedRefs)"
echo "chat pods: probes and shutdown"
sp="$(jp deploy/chat "$C.startupProbe.httpGet.path}")"; ft="$(jp deploy/chat "$C.startupProbe.failureThreshold}")"; per="$(jp deploy/chat "$C.startupProbe.periodSeconds}")"
budget=0; [[ -n "$sp" ]] && budget=$(( ${ft:-3} * ${per:-10} ))
check "startupProbe on /health/ready with a budget of at least 30 s (got ${sp:-none}, ${budget}s)" bash -c '[[ "$1" == /health/ready && "$2" -ge 30 ]]' _ "$sp" "$budget"
lp="$(jp deploy/chat "$C.livenessProbe.httpGet.path}")"
check "livenessProbe does not use /health/ready (got ${lp:-none})" bash -c '[[ -n "$1" && "$1" != /health/ready ]]' _ "$lp"
check_eq "readinessProbe: httpGet on /health/ready" /health/ready "$(jp deploy/chat "$C.readinessProbe.httpGet.path}")"
ps="$(jp deploy/chat "$C.lifecycle.preStop.sleep.seconds}")"; grace="$(jp deploy/chat '{.spec.template.spec.terminationGracePeriodSeconds}')"
check "preStop sleep of at least 6 s and a grace period of at least preStop + 8 s (preStop ${ps:-none}, grace ${grace:-?})" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -ge 6 && "$2" =~ ^[0-9]+$ && "$2" -ge $(( $1 + 8 )) ]]' _ "${ps:-x}" "${grace:-x}"
echo "autoscaling and picker configuration"
check_eq "ScaledObject chat reads 'inflight' with the metrics-api scaler" "metrics-api inflight" "$(jp scaledobject/chat "$S.triggers[0].type}") $(jp scaledobject/chat "$S.triggers[0].metadata.valueLocation}")"
why "Lesson 09: running saturates at the slots, waiting oscillates; in-flight is the demand."
tv="$(jp scaledobject/chat "$S.triggers[0].metadata.targetValue}")"
check "targetValue equals the slots per replica, 3 (got ${tv:-none})" bash -c '[[ "$1" == 3 ]]' _ "$tv"
check_ge "maxReplicaCount allows at least 4 replicas" 4 "$(jp scaledobject/chat "$S.maxReplicaCount}")"
check "pollingInterval <= 10 s and scaleDown stabilizationWindowSeconds <= 30 s in the lab" bash -c '[[ -n "$1" && "$1" -le 10 && -n "$2" && "$2" -le 30 ]]' _ "$(jp scaledobject/chat "$S.pollingInterval}")" "$(jp scaledobject/chat "$S.advanced.horizontalPodAutoscalerConfig.behavior.scaleDown.stabilizationWindowSeconds}")"
btp="$(kubectl get backendtrafficpolicy -o jsonpath='{range .items[*]}{.spec.targetRefs[0].name}:{.spec.loadBalancer.endpointOverride.extractFrom[0].header}:{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{"\n"}{end}' 2>/dev/null | grep '^chat:' | head -n 1)"
check_eq "The picker's answer is honoured: a BackendTrafficPolicy on HTTPRoute chat with endpointOverride from x-gateway-destination-endpoint, Accepted" "chat:x-gateway-destination-endpoint:True" "$btp"
why "The picker (epp) is called by the Gateway's EnvoyExtensionPolicy, but nothing makes Envoy use the endpoint it returns."

echo "behaviour: routing"
_ready_chat() { [[ "$(ready_pods app=chat)" -ge 2 ]]; }
(( _KD_FAIL == 0 )) && { wait_until 60 _ready_chat || true; }
_probe() { [[ "$(http_code $U -H 'content-type: application/json' -d '{"model":"summarize","messages":[{"role":"user","content":"hi"}],"max_tokens":4}')" == 200 ]]; }
_chat_epp() { epp_active $U chat; }
(( _KD_FAIL == 0 )) && { gw_wait_config edge dynamic_active_clusters override_host 45 || true; wait_until 45 _chat_epp || true; wait_until 30 _probe || true; }   # the picker's policies must have reached Envoy
c="$(ask_out -m chat -n 6 -c 2 -t 6 -w 8 $U)"; s="$(ask_out -m summarize -n 6 -c 2 -t 6 -w 8 $U)"; u="$(ask_out -m nope -n 3 $U)"
check_eq "6 of 6 chat requests answered by chat pods" 6 "$(count_matching '^200 chat-' "$c")"
check_eq "6 of 6 summarize requests answered by summarize pods" 6 "$(count_matching '^200 summarize-' "$s")"
check_eq "unknown models get 404 from the gateway" 3 "$(count_matching '^404 -$' "$u")"

if (( _KD_FAIL > 0 )); then
  echo "(the end-to-end checks - picker under saturation, scaling under load, a rollout under traffic - run once everything above passes)"
  exit 1
fi
echo "behaviour: the picker avoids a saturated chat replica"
_epp() { epp_active $U chat; }
wait_until 30 _epp || true
busy="$(pod_names app=chat | awk '{print $1}')"
sim_admin "$(pod_ip "$busy")" '{"fake-metrics":{"running-requests":0,"waiting-requests":0,"kv-cache-usage":0.95}}'
sleep 4
out="$(ask_out -m chat -n 30 -c 3 -t 4 -w 6 $U)"
b="$(count_of "200 $busy" "$out")"; tot="$(count_of '200 *' "$out")"
check "30 chat requests: all answered, the saturated replica got at most 5 (answered ${tot:-0}, saturated: ${b:-?})" bash -c '[[ "$1" -eq 30 && "$2" -le 5 ]]' _ "${tot:-0}" "${b:-99}"
kubectl delete pod "$busy" --wait=false >/dev/null 2>&1      # its metrics stay faked; the replacement reports the truth
settle chat 60 || true

echo "behaviour: chat scales out under load"
load_up users 9 $U -m chat -t 20 -w 25
_scaled() { [[ "$(ready_pods app=chat)" -ge 3 ]]; }
wait_until 90 _scaled || true
check_ge "With 9 users the chat Deployment reaches at least 3 ready replicas (now: $(ready_pods app=chat))" 3 "$(ready_pods app=chat)"
why "kubectl get scaledobject,hpa; kubectl exec client -- curl -s http://aggregator/"
load_down users
sleep 3

echo "behaviour: a rollout under traffic drops nothing"
o="$(mktemp)"
kubectl exec client -- ask -m chat -n 60 -c 6 -t 20 -w 25 $U > "$o" 2>/dev/null &
lp=$!
sleep 5
kubectl rollout restart deploy/chat >/dev/null 2>&1
kubectl rollout status deploy/chat --timeout=120s >/dev/null 2>&1
wait "$lp" 2>/dev/null
ro="$(cat "$o")"; rm -f "$o"
check_eq "All 60 chat requests sent during a rollout restart answered 200 (got $(count_matching '^200 ' "$ro"))" 60 "$(count_matching '^200 ' "$ro")"
why "Requests cut mid-answer or sent to a pod that stopped listening: preStop + grace period (lesson 11); pods that were not really ready (lesson 03)."
check_ge "Chat has at least 2 ready replicas after the rollout" 2 "$(ready_pods app=chat)"
