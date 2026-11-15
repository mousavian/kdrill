source "$KDRILL_HOME/courses/training/lib.sh"
check "Deployment train is gone" bash -c '! kubectl get deployment train >/dev/null 2>&1'
why "A Deployment restarts a process that exits, forever. kubectl delete deployment train"
check "Job train exists" kubectl get job train
why "kubectl apply -f job.yaml (kind: Job, restartPolicy: Never). See: kdrill hint"
if kubectl get job train >/dev/null 2>&1; then
  check_eq "Job train runs the ml-tiny image" "$ML_IMAGE" "$(jp job/train '{.spec.template.spec.containers[0].image}')"
  check "Job train's pods use restartPolicy Never or OnFailure" bash -c '[[ "$1" == Never || "$1" == OnFailure ]]' _ "$(jp job/train '{.spec.template.spec.restartPolicy}')"
  st="$(job_state train)"
  if [[ "$st" == running || "$st" == pending ]]; then
    check "Job train has finished (it is still training, $(progress_msg train); about 30-60 s in all)" false
    why "Wait and run kdrill verify again: kubectl get job train -w"
  else
    check_eq "Job train completed" complete "$st"
    why "kubectl describe job train; kubectl logs job/train"
    logs="$(job_logs train)"
    steps="$(printf '%s\n' "$logs" | sed -n 's/.*done: step \([0-9]*\) .*/\1/p' | tail -n 1)"
    check_ge "The run trained all 400 steps (logged: done: step ${steps:-?})" 400 "${steps:-0}"
    why "Keep --steps 400: a shorter run is not the same model."
    loss="$(final_loss "$logs")"
    check "The final loss is below 2.9 (got ${loss:-none})" float_lt "$loss" 2.9
    check_eq "The Job did it with one pod (no retries were needed)" 1 "$(job_pods train | grep -c .)"
    check_eq "ConfigMap result has final_loss as printed in the log" "${loss:-<none in the log>}" "$(jp configmap/result '{.data.final_loss}')"
    why "kubectl logs job/train | tail -n 1 shows final_loss=...; kubectl create configmap result --from-literal=final_loss=<value>"
  fi
fi
