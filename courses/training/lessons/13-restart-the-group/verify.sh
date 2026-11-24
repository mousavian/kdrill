source "$KDRILL_HOME/courses/training/lib.sh"
check "Job ddp exists" kubectl get job ddp
kubectl get job ddp >/dev/null 2>&1 || exit 1
check_eq "Still two workers (Indexed, completions 2, parallelism 2, WORLD_SIZE 2)" "Indexed 2 2 2" \
  "$(jp job/ddp '{.spec.completionMode} {.spec.completions} {.spec.parallelism}') $(env_of job/ddp WORLD_SIZE)"
check_eq "backoffLimit is still 0" 0 "$(jp job/ddp '{.spec.backoffLimit}')"
why "Retrying everything is not the fix: only disruptions should be free."
check_eq "STEPS 1500, CKPT_EVERY 100, checkpoints on PVC checkpoints" "1500 100 checkpoints" \
  "$(env_of job/ddp STEPS) $(env_of job/ddp CKPT_EVERY) $(jp job/ddp '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}')"
ig="$(jp job/ddp '{range .spec.podFailurePolicy.rules[?(@.action=="Ignore")]}{.onPodConditions[*].type}{" "}{end}')"
check "podFailurePolicy ignores evicted workers (DisruptionTarget)" bash -c '[[ " $1 " == *" DisruptionTarget "* ]]' _ "$ig"
ic="$(jp job/ddp '{range .spec.podFailurePolicy.rules[?(@.action=="Ignore")]}{.onExitCodes.operator}:{.onExitCodes.values[*]}{"\n"}{end}')"
check "podFailurePolicy ignores workers that stopped because a peer left (exit code 75)" bash -c 'printf "%s\n" "$1" | grep -Eq "^In:(.* )?75( |$)"' _ "$ic"

uid="$(jp job/ddp '{.metadata.uid}')"
if [[ "$(baseline_get evicted)" != "$uid" ]]; then
  st="$(job_state ddp)"
  if [[ "$st" == complete || "$st" == failed ]]; then
    check "A worker was evicted while the group trained (the Job already ended: re-create it, verify while it trains)" false
    exit 1
  fi
  pod="$(kubectl get pods -l batch.kubernetes.io/job-name=ddp,batch.kubernetes.io/job-completion-index=1 --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  p0="$(kubectl get pods -l batch.kubernetes.io/job-name=ddp,batch.kubernetes.io/job-completion-index=0 --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  at="$( [[ -n "$p0" ]] && pod_step "$p0" || echo 0)"
  if [[ -z "$pod" || "$at" -lt 150 ]]; then
    check "The group is past step 150, so verify can evict a worker (now ${at:-0}; verify again shortly)" false
    exit 1
  fi
  if (( at > 1300 )); then
    check "The run is not too close to its end to be evicted (step $at; re-create the Job or kdrill reset)" false
    exit 1
  fi
  info "evicting worker 1 ($pod) at step ~$at..."
  evict "$pod" || { check "Eviction of $pod" false; exit 1; }
  baseline_set evicted "$uid"; baseline_set evicted_at "$at"
  regrouped() {
    job_failed ddp && return 0
    local n=0 p
    for p in $(kubectl get pods -l batch.kubernetes.io/job-name=ddp --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      [[ "$p" == "$pod" || "$p" == "$p0" ]] && continue
      kubectl logs "$p" 2>/dev/null | grep -q "all 2 workers connected" && n=$((n+1))
    done
    (( n == 2 ))
  }
  wait_until 90 regrouped || true
  sleep 3
fi
at="$(baseline_get evicted_at)"
st="$(job_state ddp)"
check "The Job did not fail when a worker was evicted" test "$st" != failed
why "kubectl get job ddp -o yaml: the Failed condition's reason and message say which pod counted."
check_eq "No worker failure was counted (status.failed)" 0 "$(( $(jp job/ddp '{.status.failed}') + 0 ))"
inspect_up checkpoints
m=/mnt/checkpoints/metrics.json
set -- $(mget $m runs.-1.start_step runs.-1.world_size len:runs | paste -sd' ' -)
check "Both workers restarted together and resumed from the checkpoint (evicted at ~${at:-?}; new attempt started at ${1:-?} with ${2:-?} workers)" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && "$3" =~ ^[0-9]+$ && $1 -ge $3 && "$2" == 2 && $4 -ge 2 ]]' _ "${1:-}" "${2:-}" "${at:-x}" "${3:-0}"
inspect_down
if [[ "$st" == complete || "$st" == failed ]]; then
  check_eq "Job ddp completed" complete "$st"
else
  check "Job ddp has finished after the restart ($(progress_msg ddp); verify again when it completes)" false
fi
