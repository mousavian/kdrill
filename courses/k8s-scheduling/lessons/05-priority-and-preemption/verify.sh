live() {  # live PHASE SELECTOR -> count of non-terminating pods in that phase
  kubectl get pods -l "$2" --no-headers -o custom-columns=DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | awk -v ph="$1" '$1=="<none>" && $2==ph' | wc -l | tr -d ' '
}

pc_value="$(jp priorityclass/critical-priority '{.value}')"
check_ge "PriorityClass critical-priority exists with a value above 0" 1 "$pc_value"
why "Create it: kubectl create priorityclass critical-priority --value=1000"
gd="$(jp priorityclass/critical-priority '{.globalDefault}')"
check "critical-priority is not the global default" bash -c '[[ -n "$2" && "$1" != true ]]' _ "$gd" "$pc_value"
why "globalDefault: true would give EVERY pod without a class that priority, including batch. Leave it false."
pp="$(jp priorityclass/critical-priority '{.preemptionPolicy}')"
check "critical-priority keeps the default preemptionPolicy (PreemptLowerPriority)" bash -c '[[ -n "$2" && ( -z "$1" || "$1" == PreemptLowerPriority ) ]]' _ "$pp" "$pc_value"
why "preemptionPolicy: Never means pods of this class wait instead of evicting lower-priority pods."

check_eq "critical uses priorityClassName critical-priority" critical-priority "$(jp deploy/critical '{.spec.template.spec.priorityClassName}')"
why "Set spec.template.spec.priorityClassName on the critical Deployment."
check_eq "critical: 2 replicas, both ready" 2 "$(jp deploy/critical '{.status.readyReplicas}')"
why "Pending critical pods? Check kubectl describe pod and that the PriorityClass is assigned to the pod template."

check_eq "batch still has spec.replicas 4" 4 "$(jp deploy/batch '{.spec.replicas}')"
why "Don't scale batch down. Priority should make room instead."
check_eq "batch has exactly 2 Running pods (the rest were preempted)" 2 "$(live Running app=batch)"
check_eq "batch has 2 Pending pods waiting for room" 2 "$(live Pending app=batch)"
why "Deleted/scaled batch, or shrank its requests? Neither is allowed. Preemption evicts the pods; the Deployment recreates them as Pending."
check_eq "batch pod template has no priorityClassName" "" "$(jp deploy/batch '{.spec.template.spec.priorityClassName}')"
check_eq "batch still requests 2 CPU per pod" 2000 "$(cpu_millis "$(jp deploy/batch '{.spec.template.spec.containers[0].resources.requests.cpu}')")"
check_eq "There are still exactly 2 worker nodes" 2 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
