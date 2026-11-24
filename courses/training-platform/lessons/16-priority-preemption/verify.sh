source "$KDRILL_HOME/courses/training-platform/lib.sh"
cq=clusterqueue.kueue.x-k8s.io/training-cq
check_eq "ClusterQueue training-cq keeps its quota" "$(baseline_get quota)" "$(jp $cq '{.spec.resourceGroups}')"
pre="$(jp $cq '{.spec.preemption.withinClusterQueue}')"
check "training-cq lets higher-priority workloads preempt lower ones (withinClusterQueue: ${pre:-unset})" \
  bash -c '[[ "$1" == LowerPriority || "$1" == LowerOrNewerEqualPriority ]]' _ "$pre"
check "Job pretrain exists" kubectl get job pretrain
check_eq "pretrain is unchanged (priority low, 6000 steps, checkpoints on the PVC)" "low 6000 checkpoints" \
  "$(jp job/pretrain '{.metadata.labels.kueue\.x-k8s\.io/priority-class}') $(env_of job/pretrain STEPS) $(jp job/pretrain '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}')"
check "Job urgent-eval exists" kubectl get job urgent-eval
kubectl get job urgent-eval >/dev/null 2>&1 || exit 1
check_eq "urgent-eval goes through queue training with priority class urgent" "training urgent" \
  "$(jp job/urgent-eval '{.metadata.labels.kueue\.x-k8s\.io/queue-name} {.metadata.labels.kueue\.x-k8s\.io/priority-class}')"
check_eq "urgent-eval still requests 1 CPU" 1 "$(jp job/urgent-eval '{.spec.template.spec.containers[0].resources.requests.cpu}')"
why "Shrinking the job so both fit is not the point: the quota is for one job."
wp="$(wl_of Job pretrain)"; wu="$(wl_of Job urgent-eval)"
check "urgent-eval has a Workload" test -n "$wu"
[[ -n "$wu" && -n "$wp" ]] || exit 1
su="$(job_state urgent-eval)"
if [[ "$su" != complete ]]; then
  if [[ "$(wl_cond "$wu" QuotaReserved)" != True ]]; then
    check "urgent-eval was admitted (it waits: kubectl describe workload $wu | tail)" false
  else
    check "urgent-eval has finished (admitted, $(progress_msg urgent-eval); about 20 s)" false
  fi
  exit 1
fi
check "urgent-eval completed" true
# After re-admission Kueue sets Evicted/Preempted back to False but keeps the
# story in the Preempted message ("Previously: Preempted to accommodate ...")
# and in the Requeued condition's reason.
ev="$(jp workloads.kueue.x-k8s.io/$wp '{.status.conditions[?(@.type=="Preempted")].message} {.status.conditions[?(@.type=="Requeued")].reason}')"
check "pretrain's Workload was preempted (kubectl describe workload $wp)" bash -c '[[ "$1" == *"Preempted to accommodate"* || "$1" == *" Preempted"* ]]' _ "$ev"
fp="$(wl_time "$wp" Finished)"; qu="$(wl_time "$wu" QuotaReserved)"
check "urgent-eval ran while pretrain was unfinished" bash -c '[[ -z "$1" || "$2" < "$1" ]]' _ "$fp" "$qu"
sp="$(job_state pretrain)"
if [[ "$sp" == suspended || "$(wl_cond "$wp" QuotaReserved)" != True && "$sp" != complete ]]; then
  check "pretrain was admitted again after urgent-eval (now: $sp; give Kueue a few seconds)" false
  exit 1
fi
started() { [[ -n "$(running_pod_of pretrain)" ]] && kubectl logs "$(running_pod_of pretrain)" 2>/dev/null | grep -Eq "resumed from|starting at step"; }
[[ "$sp" == complete ]] || wait_until 40 started || true
inspect_up checkpoints
m=/mnt/checkpoints/metrics.json
set -- $(mget $m runs.-2.end runs.-2.end_step runs.-1.start_step | paste -sd' ' -)
check "pretrain stopped with a checkpoint when it was preempted (previous attempt: ${1:-?} at step ${2:-?})" test "${1:-}" = preempted
check "pretrain resumed where it stopped (step ${2:-?}), not from 0 (resumed at ${3:-?})" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && $2 -gt 0 && $2 -ge $1 ]]' _ "${2:-}" "${3:-}"
inspect_down
