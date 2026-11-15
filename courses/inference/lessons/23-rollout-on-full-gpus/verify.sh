source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
R='{.spec.strategy.rollingUpdate'
sur="$(jp deploy/llm "$R.maxSurge}")"; unav="$(jp deploy/llm "$R.maxUnavailable}")"
check "maxSurge is at least 1 (a replacement may start before an old replica stops: ${sur:-?})" bash -c '[[ "$1" =~ ^[1-9][0-9]*$ ]]' _ "${sur:-x}"
check "maxUnavailable is 0 (no old replica stops before its replacement is ready: ${unav:-?})" bash -c '[[ "$1" == 0 || "$1" == 0% ]]' _ "${unav:-x}"
check "The pod template tolerates the spare pool's taint capacity=spare:NoSchedule" \
  bash -c '[[ "$(kubectl get deploy llm -o jsonpath="{range .spec.template.spec.tolerations[*]}{.key}={.value}:{.effect}{\"\\n\"}{end}")" == *"capacity=spare:NoSchedule"* || "$(kubectl get deploy llm -o jsonpath="{.spec.template.spec.tolerations[*].operator}")" == *Exists* ]]'
why "Without it the surge pod cannot use the spare node and stays Pending (all 4 main GPUs are taken)."
pdb="$(kubectl get pdb -o jsonpath='{range .items[*]}{.spec.selector.matchLabels.app}|{.spec.minAvailable}|{.spec.maxUnavailable}{"\n"}{end}' 2>/dev/null | awk -F'|' '$1=="llm"{print; exit}')"
pmin="$(echo "$pdb" | awk -F'|' '{print $2}')"; pmax="$(echo "$pdb" | awk -F'|' '{print $3}')"
check "A PodDisruptionBudget on app=llm keeps all 4 replicas (minAvailable 4 or maxUnavailable 0; got: ${pdb:-none})" \
  bash -c '[[ -n "$1" ]] && { [[ "$2" =~ ^[0-9]+$ && "$2" -ge 4 ]] || [[ "$3" == 0 ]]; }' _ "$pdb" "$pmin" "$pmax"
if (( _KD_FAIL == 0 )); then
  kubectl set env deploy/llm MODEL_VERSION=v2 >/dev/null
  min=9; spare_seen=0; finished=0; end=$((SECONDS + 60))
  while (( SECONDS < end )); do
    r="$(ready_pods app=llm)"; (( r < min )) && min=$r
    if [[ "$(kubectl get pods -l app=llm -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | grep -c '^spare-1$')" -ge 1 ]]; then spare_seen=1; fi
    if [[ "$(kubectl get pods -l app=llm -o jsonpath='{range .items[*]}{.status.phase}{" "}{.spec.containers[0].env[?(@.name=="MODEL_VERSION")].value}{"\n"}{end}' 2>/dev/null | grep -c '^Running v2$')" == 4 && "$(kubectl get pods -l app=llm --no-headers | wc -l | tr -d ' ')" == 4 ]]; then finished=1; break; fi
    sleep 1
  done
  check_eq "A rollout to v2 (run by verify) completes within 60 s" 1 "$finished"
  check_ge "... with at least 4 ready replicas the whole time (lowest seen: $min)" 4 "$min"
  check_eq "... using the spare node for the surge pod" 1 "$spare_seen"
  check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
  check_eq "Replicas 4 and 1 GPU each, as before" "4 1" "$(jp deploy/llm '{.spec.replicas}') $(res_limit nvidia.com/gpu deploy/llm)"
else
  echo "(the rollout test - capacity sampled every second while v2 rolls out - runs once the checks above pass)"
fi
check_fleet_unchanged
