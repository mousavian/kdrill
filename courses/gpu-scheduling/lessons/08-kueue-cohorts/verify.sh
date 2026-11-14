source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"

check_eq "team-a-cq and team-b-cq are both in cohort research" "research research" \
  "$(jp clusterqueue/team-a-cq '{.spec.cohortName}') $(jp clusterqueue/team-b-cq '{.spec.cohortName}')"
why "Set spec.cohortName: research on both ClusterQueues. Queues in a cohort can borrow each other's unused quota."
rc="$(jp clusterqueue/team-b-cq '{.spec.preemption.reclaimWithinCohort}')"
check "team-b-cq may reclaim its lent quota (preemption.reclaimWithinCohort: Any)" bash -c '[[ "$1" == Any || "$1" == LowerPriority ]]' _ "$rc"
why "Default is Never: a lender then waits until the borrower finishes. Set spec.preemption.reclaimWithinCohort: Any."
check_eq "Quotas unchanged (4 GPUs nominal per team)" "$(kubectl -n "$KDRILL_NS" get cm kdrill-baseline -o jsonpath='{.data.extra}' 2>/dev/null)" "$(quotas)"
why "Raising team-a's quota hides the problem. Use the cohort to share idle quota instead."

check_eq "team-a still has both Jobs (exp-1, exp-2)" "exp-1 exp-2" "$(kubectl -n team-a get jobs -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)"
check_eq "team-b submitted its Job eval-b (manifests/team-b-job.yaml)" eval-b "$(kubectl -n team-b get jobs -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)"
check_eq "eval-b is admitted by Kueue" admitted "$(wl_state team-b eval-b)"
check_eq "eval-b's pod is Running" 1 "$(job_running eval-b team-b)"
why "kubectl -n team-b describe workload; kubectl describe clusterqueue team-b-cq"

adm=0; pend=0
for j in exp-1 exp-2; do
  case "$(wl_state team-a $j)" in
    admitted) [[ "$(job_running $j team-a)" == 1 ]] && adm=$((adm+1)) ;;
    pending)  [[ "$(job_pods $j team-a)" == 0 ]] && pend=$((pend+1)) ;;
  esac
done
check_eq "team-a: one Job running on its own quota, one back in the queue" "1 1" "$adm $pend"
reasons="$(kubectl -n team-a get workloads -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Preempted")].reason} {.status.schedulingStats.evictions[*].reason}{"\n"}{end}' 2>/dev/null)"
check "a borrowing team-a Job was preempted by in-cohort reclamation" bash -c '[[ "$1" == *InCohortReclamation* ]]' _ "$reasons"
why "Order matters: first let team-a borrow (exp-2 Running), then submit eval-b so Kueue has to reclaim. kdrill reset to try again."
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 1 node" 1 "$(fake_node_count)"
check_fleet_unchanged
