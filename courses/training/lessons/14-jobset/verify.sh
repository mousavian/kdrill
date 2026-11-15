source "$KDRILL_HOME/courses/training/lib.sh"
js=jobset.jobset.x-k8s.io/ddp
check "JobSet ddp exists" kubectl get $js
kubectl get $js >/dev/null 2>&1 || exit 1
c='{.spec.replicatedJobs[0].template.spec.template.spec.containers[0]'
envv() { jp $js "$c.env[?(@.name==\"$1\")].value}"; }
check_eq "Two workers: one Indexed Job with completions 2, parallelism 2, WORLD_SIZE 2" "1 Indexed 2 2 2" \
  "$(jp $js '{.spec.replicatedJobs[0].replicas} {.spec.replicatedJobs[0].template.spec.completionMode} {.spec.replicatedJobs[0].template.spec.completions} {.spec.replicatedJobs[0].template.spec.parallelism}') $(envv WORLD_SIZE)"
check_eq "STEPS 1500, CKPT_EVERY 100, checkpoints on PVC checkpoints" "1500 100 checkpoints" \
  "$(envv STEPS) $(envv CKPT_EVERY) $(jp $js '{.spec.replicatedJobs[0].template.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}')"
check_eq "The child Job still fails on the first failed pod (backoffLimit 0)" 0 "$(jp $js '{.spec.replicatedJobs[0].template.spec.backoffLimit}')"
why "Restarting is the JobSet's job here, not the Job's."
ma="$(envv MASTER_ADDR)"
check "MASTER_ADDR is rank 0's JobSet DNS name (got ${ma:-unset})" bash -c '[[ "$1" == ddp-workers-0-0.ddp || "$1" == ddp-workers-0-0.ddp.train* ]]' _ "$ma"
why "<jobset>-<replicatedJob>-<job index>-<pod index>.<jobset>"
mr="$(jp $js '{.spec.failurePolicy.maxRestarts}')"
check "failurePolicy.maxRestarts is 1-5 (got ${mr:-unset})" bash -c '[[ "$1" =~ ^[1-5]$ ]]' _ "$mr"

uid="$(jp $js '{.metadata.uid}')"
jscond() { jp $js "{.status.conditions[?(@.type==\"$1\")].status}"; }
if [[ "$(baseline_get evicted)" != "$uid" ]]; then
  if [[ "$(jscond Completed)" == True || "$(jscond Failed)" == True ]]; then
    check "A worker was evicted while the JobSet trained (it already ended: re-create it and verify while it trains)" false
    exit 1
  fi
  pod="$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=ddp,batch.kubernetes.io/job-completion-index=1 --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  p0="$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=ddp,batch.kubernetes.io/job-completion-index=0 --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  at="$( [[ -n "$p0" ]] && pod_step "$p0" || echo 0)"
  if [[ -z "$pod" || "$at" -lt 150 ]]; then
    check "The workers are past step 150, so verify can evict one (now ${at:-0}; verify again shortly)" false
    exit 1
  fi
  if (( at > 1300 )); then
    check "The run is not too close to its end to be evicted (step $at; re-create the JobSet or kdrill reset)" false
    exit 1
  fi
  info "evicting worker 1 ($pod) at step ~$at..."
  evict "$pod" || { check "Eviction of $pod" false; exit 1; }
  baseline_set evicted "$uid"; baseline_set evicted_at "$at"
  restarted() {
    [[ "$(jscond Failed)" == True ]] && return 0
    local n=0 p
    [[ "$(jp $js '{.status.restarts}')" =~ ^[1-9] ]] || return 1
    for p in $(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=ddp --field-selector=status.phase=Running -o name 2>/dev/null); do
      kubectl logs "$p" 2>/dev/null | grep -q "all 2 workers connected" && n=$((n+1))
    done
    (( n == 2 ))
  }
  wait_until 100 restarted || true
  sleep 3
fi
at="$(baseline_get evicted_at)"
check "The JobSet did not fail" test "$(jscond Failed)" != True
why "kubectl get jobset ddp -o yaml (status.conditions); without maxRestarts the first failed child Job fails the set."
check_ge "The JobSet restarted its workers after the eviction (status.restarts)" 1 "$(jp $js '{.status.restarts}')"
inspect_up checkpoints
set -- $(mget /mnt/checkpoints/metrics.json runs.-1.start_step runs.-1.world_size | paste -sd' ' -)
check "The restarted workers resumed from the checkpoint (evicted at ~${at:-?}; restarted at ${1:-?} with ${2:-?} workers)" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -ge $3 && "$2" == 2 ]]' _ "${1:-}" "${2:-}" "${at:-x}"
inspect_down
if [[ "$(jscond Completed)" == True ]]; then
  check "JobSet ddp completed" true
else
  check "JobSet ddp has completed (training again after the restart, verify again in a minute)" false
fi
