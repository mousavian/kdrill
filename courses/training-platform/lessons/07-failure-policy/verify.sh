source "$KDRILL_HOME/courses/training-platform/lib.sh"
for j in buggy steady; do
  if ! kubectl get job "$j" >/dev/null 2>&1; then check "Job $j exists" false; continue; fi
  fj="$(jp job/$j '{range .spec.podFailurePolicy.rules[?(@.action=="FailJob")]}{.onExitCodes.operator}:{.onExitCodes.values[*]}{"\n"}{end}')"
  check "$j: podFailurePolicy fails the Job on exit code 42" bash -c 'printf "%s\n" "$1" | grep -Eq "^In:(.* )?42( |$)"' _ "$fj"
  ig="$(jp job/$j '{range .spec.podFailurePolicy.rules[?(@.action=="Ignore")]}{.onPodConditions[*].type}{" "}{end}')"
  check "$j: podFailurePolicy ignores pods with the DisruptionTarget condition" bash -c '[[ " $1 " == *" DisruptionTarget "* ]]' _ "$ig"
  bl="$(jp job/$j '{.spec.backoffLimit}')"
  check "$j: backoffLimit is 3 or less (got $bl)" bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -le 3 ]]' _ "$bl"
  ad="$(jp job/$j '{.spec.activeDeadlineSeconds}')"
  check "$j: activeDeadlineSeconds between 60 and 3600 (got ${ad:-unset})" bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -ge 60 && $1 -le 3600 ]]' _ "$ad"
  tt="$(jp job/$j '{.spec.ttlSecondsAfterFinished}')"
  check "$j: ttlSecondsAfterFinished between 300 and 86400 (got ${tt:-unset})" bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -ge 300 && $1 -le 86400 ]]' _ "$tt"
done

# ---- buggy: the bug must stay, and the Job must stop at the first crash
if kubectl get job buggy >/dev/null 2>&1; then
  check_eq "buggy still has its bug (FAIL_AT_STEP=50)" 50 "$(env_of job/buggy FAIL_AT_STEP)"
  why "The point is to stop retrying a bug, not to remove it."
  bs="$(job_state buggy)"
  if [[ "$bs" == running || "$bs" == pending ]]; then
    check "buggy has stopped (it is still retrying: $(jp job/buggy '{.status.failed}') failed pod(s) so far)" false
  else
    check_eq "buggy failed because of the policy (reason)" PodFailurePolicy "$(jp job/buggy '{.status.conditions[?(@.type=="Failed")].reason}')"
    check_eq "buggy failed after one pod" 1 "$(( $(jp job/buggy '{.status.failed}') + 0 ))"
  fi
fi

# ---- steady: verify evicts its pod once, then it must carry on
kubectl get job steady >/dev/null 2>&1 || exit 1
uid="$(jp job/steady '{.metadata.uid}')"
if [[ "$(baseline_get evicted)" != "$uid" ]]; then
  ss="$(job_state steady)"
  pod="$(running_pod_of steady)"
  if [[ "$ss" == complete || "$ss" == failed ]]; then
    check "steady was evicted once while it trained (it already finished: kdrill reset, or re-create steady, and verify while it runs)" false
    exit 1
  fi
  if [[ -z "$pod" || "$(pod_step "$pod")" -lt 25 ]]; then
    check "steady is training, so verify can evict it (not yet: verify again in a few seconds)" false
    exit 1
  fi
  info "evicting pod $pod of job steady (as kubectl drain would)..."
  if evict "$pod"; then baseline_set evicted "$uid"; else check "Eviction of $pod" false; exit 1; fi
  gone() { ! kubectl get pod "$pod" >/dev/null 2>&1; }
  wait_until 40 gone || true
  sleep 2
fi
fl="$(( $(jp job/steady '{.status.failed}') + 0 ))"
check_eq "steady: the evicted pod was not counted as a failure (status.failed)" 0 "$fl"
why "Ignore pods that have the DisruptionTarget condition; otherwise backoffLimit 0 fails the Job on the first drain."
ss="$(job_state steady)"
check "steady did not fail" test "$ss" != failed
if [[ "$ss" == running || "$ss" == pending ]]; then
  check "steady has finished after its eviction (now $(progress_msg steady); about a minute)" false
  why "Run kdrill verify again when it completes."
else
  check_eq "steady completed" complete "$ss"
fi
