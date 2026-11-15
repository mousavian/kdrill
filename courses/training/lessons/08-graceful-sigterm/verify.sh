source "$KDRILL_HOME/courses/training/lib.sh"
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
check_eq "STEPS, CKPT_EVERY and CKPT_WRITE_SECONDS are unchanged (1200 400 5)" "1200 400 5" \
  "$(env_of job/train STEPS) $(env_of job/train CKPT_EVERY) $(env_of job/train CKPT_WRITE_SECONDS)"
why "Checkpointing more often only hides the problem; the slow checkpoint is the realistic part."
check "Checkpoints are on the PVC checkpoints" bash -c '[[ " $1 " == *" checkpoints "* ]]' _ "$(jp job/train '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')"
gp="$(jp job/train '{.spec.template.spec.terminationGracePeriodSeconds}')"
check "terminationGracePeriodSeconds leaves time for a 5 s checkpoint (15-120 s; got ${gp:-default 30})" \
  bash -c 'v=${1:-30}; [[ "$v" =~ ^[0-9]+$ && $v -ge 15 && $v -le 120 ]]' _ "$gp"

uid="$(jp job/train '{.metadata.uid}')"
if [[ "$(baseline_get evicted)" != "$uid" ]]; then
  st="$(job_state train)"
  if [[ "$st" == complete || "$st" == failed ]]; then
    check "The run was evicted while training (it already ended: re-create the Job and verify while it trains)" false
    exit 1
  fi
  pod="$(running_pod_of train)"; at="$( [[ -n "$pod" ]] && pod_step "$pod" || echo 0)"
  if [[ -z "$pod" || "$at" -lt 100 ]]; then
    check "The run is past step 100, so verify can evict it (now ${at:-0}; verify again shortly)" false
    exit 1
  fi
  if (( at > 1100 )); then
    check "The run is not too close to its end to be evicted (step $at; kdrill reset)" false
    exit 1
  fi
  info "evicting pod $pod at step $at (as a node drain or spot reclaim would)..."
  evict "$pod" || { check "Eviction of $pod" false; exit 1; }
  baseline_set evicted "$uid"; baseline_set evicted_at "$at"; baseline_set evicted_pod "$pod"
  gone() { ! kubectl get pod "$pod" >/dev/null 2>&1; }
  wait_until 130 gone || true
  started() { [[ -n "$(running_pod_of train)" ]] && kubectl logs "$(running_pod_of train)" 2>/dev/null | grep -Eq "resumed from|starting at step"; }
  wait_until 60 started || true
  sleep 2
fi
at="$(baseline_get evicted_at)"
inspect_up checkpoints
m=/mnt/checkpoints/metrics.json
n="$(mget1 $m len:runs)"
last="$(mget $m runs.-1.start_step runs.-2.end runs.-2.end_step | paste -sd' ' -)"
set -- $last
check "The evicted attempt stopped on SIGTERM and saved (metrics.json: previous attempt end=${2:-none})" test "${2:-}" = preempted
why "kubectl logs <evicted pod> shows no 'received SIGTERM': the signal never reached train, or SIGKILL came first."
check "The next attempt resumed from the step where the eviction happened (evicted at ~${at:-?}, resumed at ${1:-?})" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && $1 -ge $2 ]]' _ "${1:-}" "${at:-x}"
why "Steps lost = evicted step - resumed step. Only a checkpoint written after SIGTERM avoids losing them."
inspect_down
st="$(job_state train)"
check "The Job is still running or complete after the eviction (state: $st)" bash -c '[[ "$1" == running || "$1" == complete || "$1" == pending ]]' _ "$st"
