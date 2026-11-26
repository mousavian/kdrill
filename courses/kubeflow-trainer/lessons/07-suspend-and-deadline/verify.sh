source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
uid_of() { jp $TJ/$1 '{.metadata.uid}'; }

# --- 1. explore: suspended, not deleted
E=explore
check "TrainJob $E still exists" kubectl get $TJ $E
if kubectl get $TJ $E >/dev/null 2>&1; then
  check_eq "It is the same TrainJob as at the start (suspend it, do not recreate it)" "$(baseline_get $E)" "$(uid_of $E)"
  check_eq "spec.suspend is true and the condition Suspended is True" "true True" "$(jp $TJ/$E '{.spec.suspend}') $(tj_cond $E Suspended)"
  why "kubectl patch trainjob explore --type=merge -p '{\"spec\":{\"suspend\":true}}'"
  nopods() { [[ "$(tj_pods $E | grep -c .)" == 0 ]]; }; wait_until 25 nopods || true
  check_eq "Its JobSet is suspended and no pod of it is left" "true 0" "$(jp jobset/$E '{.spec.suspend}') $(tj_pods $E | grep -c .)"
fi

# --- 2. urgent: resumed and completed
U=urgent
check "TrainJob $U still exists" kubectl get $TJ $U
if kubectl get $TJ $U >/dev/null 2>&1; then
  check_eq "It is the same TrainJob as at the start" "$(baseline_get $U)" "$(uid_of $U)"
  check_eq "It was resumed: Suspended is False with reason Resumed" "False Resumed" "$(tj_cond $U Suspended) $(tj_reason $U Suspended)"
  why "kubectl patch trainjob urgent --type=merge -p '{\"spec\":{\"suspend\":false}}'"
fi

# --- 3. runaway: a deadline
R=runaway
check "TrainJob $R exists" kubectl get $TJ $R
if kubectl get $TJ $R >/dev/null 2>&1; then
  dl="$(jp $TJ/$R '{.spec.activeDeadlineSeconds}')"
  check "activeDeadlineSeconds is between 1 and 60 (got ${dl:-unset})" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 60 ]]' _ "$dl"
  check_eq "Its spec is otherwise unchanged (1000000 steps, seed 5)" "1000000 5" \
    "$(jp $TJ/$R '{.spec.trainer.args[1]} {.spec.trainer.args[3]}')"
fi
fail_fast

# --- wait for the two runs
end=$((SECONDS + 70))
while (( SECONDS < end )); do
  [[ "$(tj_state $U)" == complete && "$(tj_state $R)" == failed ]] && break
  sleep 2
done
check_eq "urgent has completed" complete "$(tj_state $U)"
why "It is $(tj_state $U), $(tj_progress $U). Is it resumed? Verify again in a few seconds."
logs="$(tj_logs $U node)"
check "urgent's log shows 200 steps and seed 9" bash -c 'grep -q "steps=200" <<<"$1" && grep -q "seed=9" <<<"$1" && grep -q "done: step 200" <<<"$1"' _ "$logs"
check_eq "runaway ended Failed with reason DeadlineExceeded" "True DeadlineExceeded" "$(tj_cond $R Failed) $(tj_reason $R Failed)"
why "It is $(tj_state $R). The deadline counts from the creation of the TrainJob: verify again in a moment."
check_eq "runaway's pods and JobSet were removed by the controller" "0 0" "$(tj_pods $R | grep -c .) $(kubectl get jobset $R --no-headers 2>/dev/null | grep -c .)"
