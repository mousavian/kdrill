source "$KDRILL_HOME/courses/inference/lib.sh"
R='{.spec.strategy.rollingUpdate'
sur="$(jp deploy/llm "$R.maxSurge}")"; unav="$(jp deploy/llm "$R.maxUnavailable}")"
check_eq "strategy: RollingUpdate" RollingUpdate "$(jp deploy/llm '{.spec.strategy.type}')"
why "Recreate would stop every replica at once."
check "maxSurge is 0 (no extra pod: the quota has no room; got ${sur:-?})" bash -c '[[ "$1" == 0 || "$1" == 0% ]]' _ "$sur"
check "maxUnavailable is 1 (replace one replica at a time; got ${unav:-?})" bash -c '[[ "$1" == 1 || "$1" == 25% ]]' _ "$unav"
mrs="$(jp deploy/llm '{.spec.minReadySeconds}')"
check "minReadySeconds is at least 3 (a new replica must stay ready 3 s before the next old one is taken: got ${mrs:-0})" bash -c '[[ "$1" -ge 3 ]]' _ "${mrs:-0}"
why "kubectl explain deploy.spec.minReadySeconds"
# PodDisruptionBudget matching the model pods
pdb="$(kubectl get pdb -o jsonpath='{range .items[*]}{.spec.selector.matchLabels.app}|{.spec.minAvailable}|{.spec.maxUnavailable}{"\n"}{end}' 2>/dev/null | awk -F'|' '$1=="llm"{print; exit}')"
pmin="$(echo "$pdb" | awk -F'|' '{print $2}')"; pmax="$(echo "$pdb" | awk -F'|' '{print $3}')"
check "A PodDisruptionBudget for app=llm keeps at least 3 of 4 replicas (minAvailable >= 3 or maxUnavailable <= 1; got: ${pdb:-none})" \
  bash -c '[[ -n "$1" ]] && { [[ "$2" =~ ^[0-9]+$ && "$2" -ge 3 ]] || [[ "$3" =~ ^[0-9]+$ && "$3" -le 1 ]]; }' _ "$pdb" "$pmin" "$pmax"
why "A PDB limits voluntary evictions (node drains, autoscaler): kubectl create pdb llm --selector=app=llm --min-available=3"
# the stuck rollout finishes
_done() { [[ "$(kubectl get pods -l app=llm -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{" "}{.spec.containers[0].env[?(@.name=="MODEL_VERSION")].value}{"\n"}{end}' 2>/dev/null | grep -c '^true v2$')" == 4 ]]; }
# wait only when the strategy is already right (otherwise the rollout is stuck and waiting would not help)
(( _KD_FAIL == 0 )) && { wait_until 60 _done || true; }
check "The v2 rollout completes: 4 ready replicas running MODEL_VERSION=v2" _done
why "kubectl rollout status deploy/llm; kubectl describe rs | grep -i quota -- a surge pod cannot be created (pods: 5)."
if (( _KD_FAIL == 0 )); then
  # behaviour: roll out v3 and sample the ready count every second
  kubectl set env deploy/llm MODEL_VERSION=v3 >/dev/null
  min=9; end=$((SECONDS + 90)); finished=0
  while (( SECONDS < end )); do
    r="$(ready_pods app=llm)"; (( r < min )) && min=$r
    if [[ "$(kubectl get pods -l app=llm -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{" "}{.spec.containers[0].env[?(@.name=="MODEL_VERSION")].value}{"\n"}{end}' 2>/dev/null | grep -c '^true v3$')" == 4 && "$(kubectl get pods -l app=llm --no-headers | wc -l | tr -d ' ')" == 4 ]]; then finished=1; break; fi
    sleep 1
  done
  check_eq "A second rollout (v3, run by verify) completes within 90 s" 1 "$finished"
  check "... and the Deployment never had fewer than 3 ready replicas during it (lowest seen: $min)" bash -c '[[ "$1" -ge 3 ]]' _ "$min"
  check "A completion still answers 200" chat_ok http://llm/v1/chat/completions
else
  echo "(the rollout of v3, with ready replicas sampled every second, runs once the checks above pass)"
fi
