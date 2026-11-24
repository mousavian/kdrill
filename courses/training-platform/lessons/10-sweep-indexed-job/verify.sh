source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "Job sweep exists" kubectl get job sweep
kubectl get job sweep >/dev/null 2>&1 || exit 1
check_eq "Job sweep is an Indexed Job" Indexed "$(jp job/sweep '{.spec.completionMode}')"
why "completionMode: Indexed (delete and re-create the Job)"
check_eq "It still runs 3 completions" 3 "$(jp job/sweep '{.spec.completions}')"
p="$(jp job/sweep '{.spec.parallelism}')"
check "parallelism is 1-3 (got ${p:-?})" bash -c '[[ "$1" =~ ^[1-3]$ ]]' _ "$p"
check "The learning rates are still 0.0003 0.003 0.03" bash -c '[[ "$1" == *"0.0003 0.003 0.03"* ]]' _ "$(jp job/sweep '{.spec.template.spec.containers[0].args[*]}')"
st="$(job_state sweep)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job sweep has finished ($(jp job/sweep '{.status.succeeded}') of 3 runs done; about a minute in all)" false
  exit 1
fi
check_eq "Job sweep completed" complete "$st"
inspect_up results
best=""; bestv=""; lrs=""
for i in 0 1 2; do
  set -- $(mget /mnt/results/run-$i/metrics.json lr val_loss status step | paste -sd' ' -)
  lrs+="${1:-?} "
  check_eq "run-$i finished 300 steps" "done 300" "${3:-} ${4:-}"
  if [[ -n "${2:-}" ]] && { [[ -z "$bestv" ]] || float_lt "$2" "$bestv"; }; then best="$1"; bestv="$2"; fi
done
inspect_down
check_eq "Each index trained its own learning rate (run-0..2)" "0.0003 0.003 0.03" "${lrs% }"
why "With a NonIndexed Job every pod is index 0 and writes run-0."
got="$(jp configmap/sweep-result '{.data.best-lr}')"
check "ConfigMap sweep-result has best-lr = the learning rate with the lowest val_loss (got ${got:-none})" \
  awk -v a="$got" -v b="$best" 'BEGIN{exit !(a != "" && b != "" && a+0 == b+0)}'
why "kubectl logs -l batch.kubernetes.io/job-completion-index=<i> --tail=1 shows each run's val_loss."
