source "$KDRILL_HOME/courses/inference/lib.sh"
check "The eight users are still sending (the load is part of the lesson)" bash -c '[[ "$(kubectl get deploy users -o jsonpath="{.spec.replicas}")" == 1 && "$(kubectl get deploy users -o jsonpath="{.spec.template.spec.containers[0].command[*]}")" == *"-c 8"* ]]'
check "The model server still runs 2 requests at a time (max-num-seqs 2): the fix is more replicas, not a bigger server" \
  bash -c '[[ "$(kubectl get deploy llm -o jsonpath="{.spec.template.spec.containers[0].args[*]}")" == *"--max-num-seqs 2"* ]]'
n="$(kubectl get hpa -o jsonpath='{range .items[*]}{.spec.scaleTargetRef.name}{"\n"}{end}' 2>/dev/null | grep -c '^llm$' || true)"
check_eq "No HorizontalPodAutoscaler targets Deployment llm any more" 0 "${n:-0}"
why "An HPA owns spec.replicas: it would scale a manual change back down. kubectl get hpa"
reps="$(jp deploy/llm '{.spec.replicas}')"
check_ge "Deployment llm has at least 4 replicas (8 users / 2 per replica; replicas now: ${reps:-?})" 4 "${reps:-0}"
_ready4() { [[ "$(ready_pods app=llm)" -ge 4 ]]; }
[[ "${reps:-0}" -ge 4 ]] && { wait_until 60 _ready4 || true; }
check_ge "... and at least 4 of them are ready" 4 "$(ready_pods app=llm)"
_drained() { local w; w="$(agg waiting)"; [[ -n "$w" ]] && awk -v w="$w" 'BEGIN{exit !(w+0 <= 3)}'; }
[[ "${reps:-0}" -ge 4 ]] && { wait_until 45 _drained || true; }
w="$(agg waiting)"; r="$(agg running)"
check "The queue has shrunk: ${w:-?} request(s) waiting (was 6), ${r:-?} running, summed over all replicas" awk -v w="${w:-99}" 'BEGIN{exit !(w+0 <= 3)}'
why "kubectl exec client -- curl -s http://aggregator/ shows running/waiting summed over the replicas."
check "A completion still answers 200" chat_ok http://llm/v1/chat/completions
