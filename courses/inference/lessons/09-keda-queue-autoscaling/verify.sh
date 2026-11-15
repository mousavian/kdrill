source "$KDRILL_HOME/courses/inference/lib.sh"
S='{.spec'
so() { jp scaledobject/llm "$1"; }
check "ScaledObject llm targets Deployment llm and is Ready" bash -c '[[ "$1" == llm && "$2" == True ]]' _ "$(so "$S.scaleTargetRef.name}")" "$(so '{.status.conditions[?(@.type=="Ready")].status}')"
why "kubectl describe scaledobject llm shows why KEDA cannot read the trigger."
check_eq "Trigger: type metrics-api reading the field 'inflight' (running + waiting) from the aggregator" "metrics-api inflight" \
  "$(so "$S.triggers[0].type}") $(so "$S.triggers[0].metadata.valueLocation}")"
why "'running' can never exceed the slots that exist, so it cannot ask for more replicas; 'waiting' collapses as soon as you scale out and makes the autoscaler flap. In-flight / slots per replica is the demand."
tv="$(so "$S.triggers[0].metadata.targetValue}")"
check "targetValue is 2 (the slots per replica: max-num-seqs 2) (got ${tv:-none})" bash -c '[[ "$1" == 2 || "$1" == 2.0 ]]' _ "$tv"
check_ge "maxReplicaCount allows at least 4 replicas" 4 "$(so "$S.maxReplicaCount}")"
min="$(so "$S.minReplicaCount}")"
check "minReplicaCount is 1 or 2: it autoscales, it is not a fixed size (got ${min:-?})" bash -c '[[ "$1" -ge 1 && "$1" -le 2 ]]' _ "${min:-9}"
check "pollingInterval is 10 s or less (got $(so "$S.pollingInterval}"))" bash -c '[[ -n "$1" && "$1" -le 10 ]]' _ "$(so "$S.pollingInterval}")"
check "scaleDown stabilizationWindowSeconds is 30 s or less in the lab (got $(so "$S.advanced.horizontalPodAutoscalerConfig.behavior.scaleDown.stabilizationWindowSeconds}"))" \
  bash -c '[[ -n "$1" && "$1" -le 30 ]]' _ "$(so "$S.advanced.horizontalPodAutoscalerConfig.behavior.scaleDown.stabilizationWindowSeconds}")"
why "The default is 300 s: scaling down is deliberately slow in production; the lab keeps it short."
foreign="$(kubectl get hpa -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -v '^keda-hpa-' | wc -l | tr -d ' ')"
check_eq "No other HPA exists next to KEDA's (it would fight over spec.replicas)" 0 "$foreign"
check "The users are still sending (8 concurrent) and the server is unchanged (2 slots)" bash -c '[[ "$(kubectl get deploy users -o jsonpath="{.spec.template.spec.containers[0].command[*]}")" == *"-c 8"* && "$(kubectl get deploy llm -o jsonpath="{.spec.template.spec.containers[0].args[*]}")" == *"--max-num-seqs 2"* ]]'

# --- behaviour (only once the configuration above is right)
if (( _KD_FAIL > 0 )); then
  echo "(the behaviour checks - scaling up under load and back down - run once the configuration checks pass)"
  exit 1
fi
kubectl scale deploy/users --replicas=1 >/dev/null 2>&1
_up() { [[ "$(ready_pods app=llm)" -ge 4 ]]; }
wait_until 90 _up || true
check_ge "Under 8 users the Deployment scaled up to at least 4 ready replicas (now: $(ready_pods app=llm))" 4 "$(ready_pods app=llm)"
why "kubectl get scaledobject,hpa; kubectl exec client -- curl -s http://aggregator/ shows inflight."
_calm() { local w; w="$(agg waiting_per_replica)"; [[ -n "$w" ]] && awk -v w="$w" 'BEGIN{exit !(w+0 <= 1.5)}'; }
wait_until 25 _calm || true
check "... and requests no longer queue up (waiting per replica: $(agg waiting_per_replica), at most 1.5)" _calm
why "The Service balances randomly, so a request or two may wait; a deep queue per replica means too few replicas."
if (( _KD_FAIL == 0 )); then
  kubectl scale deploy/users --replicas=0 >/dev/null 2>&1
  _down() { [[ "$(jp deploy/llm '{.spec.replicas}')" -le 2 ]]; }
  wait_until 90 _down || true
  check "When the users leave, the Deployment scales back down (spec.replicas now $(jp deploy/llm '{.spec.replicas}'), at most 2)" _down
  why "A 300 s stabilization window or a huge cooldown keeps replicas (and GPUs) idle."
  kubectl scale deploy/users --replicas=1 >/dev/null 2>&1   # give the load back for the next verify
fi
