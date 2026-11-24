source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
check_eq "STEPS is still 1000" 1000 "$(env_of job/train STEPS)"
why "Keep the run's length: a shorter run has less to lose but is not the same run."
r="$(env_of job/train RESUME)"
check "RESUME is auto (got ${r:-unset = auto})" bash -c '[[ -z "$1" || "$1" == auto ]]' _ "$r"
claims="$(jp job/train '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')"
check "Job train mounts the PVC checkpoints" bash -c '[[ " $1 " == *" checkpoints "* ]]' _ "$claims"
ce="$(env_of job/train CKPT_EVERY)"
check "CKPT_EVERY is still 100 (got ${ce:-unset})" test "${ce:-100}" = 100
pods="$(( $(jp job/train '{.status.failed}' || echo 0) + 0 ))"   # deleted pods count as failed
st="$(job_state train)"
if [[ "$st" == running || "$st" == pending ]]; then
  if (( pods < 1 )); then
    check "The run has been interrupted once (delete the pod after step 200; now $(progress_msg train))" false
    why "kubectl delete pod -l batch.kubernetes.io/job-name=train, once the log shows step 200 or later"
  else
    check "Job train has finished (resumed run $(progress_msg train); verify again when it completes)" false
  fi
  exit 1
fi
check_eq "Job train completed" complete "$st"
check_ge "The Job lost a pod mid-run (status.failed)" 1 "$pods"
why "Delete the training pod while it runs (after step 200), then let the Job finish. kdrill reset to start over."
if [[ " $claims " == *" checkpoints "* ]]; then
  inspect_up checkpoints
  m=/mnt/checkpoints/metrics.json
  n="$(mget1 $m len:runs)"
  check_ge "metrics.json records at least two attempts (runs: ${n:-0})" 2 "${n:-0}"
  starts="$(mget $m runs.0.start_step runs.1.start_step runs.-1.start_step | paste -sd' ' -)"
  set -- $starts
  check "A later attempt resumed from a checkpoint after step 0 (start steps: ${starts:-?})" bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -ge 100 ]]' _ "${2:-}"
  why "RESUME=auto and checkpoints on the PVC; the replacement pod logs 'resumed from ckpt-...'."
  check_eq "The resumed run finished all 1000 steps" "done 1000 1000" "$(mget $m status step steps | paste -sd' ' -)"
  inspect_down
fi
