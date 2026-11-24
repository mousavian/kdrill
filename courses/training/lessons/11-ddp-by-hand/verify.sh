source "$KDRILL_HOME/courses/training/lib.sh"
check "Service workers exists and is headless (clusterIP None)" test "$(jp svc/workers '{.spec.clusterIP}')" = None
why "kind: Service, spec.clusterIP: None"
check "Job ddp exists" kubectl get job ddp
kubectl get job ddp >/dev/null 2>&1 || exit 1
check_eq "The pods' subdomain matches the Service" workers "$(jp job/ddp '{.spec.template.spec.subdomain}')"
sel="$(jp svc/workers '{.spec.selector}')"
check "Service workers selects the Job's pods" bash -c '[[ "$1" == *"ddp"* ]]' _ "$sel"
check_eq "Still two workers: Indexed, completions 2, parallelism 2, WORLD_SIZE 2" "Indexed 2 2 2" \
  "$(jp job/ddp '{.spec.completionMode} {.spec.completions} {.spec.parallelism}') $(env_of job/ddp WORLD_SIZE)"
why "The task is a 2-worker run; one worker is not distributed training."
check_eq "STEPS is still 300" 300 "$(env_of job/ddp STEPS)"
st="$(job_state ddp)"
if [[ "$st" == running || "$st" == pending ]]; then
  l="$(all_job_logs ddp)"
  if printf '%s\n' "$l" | grep -q "all 2 workers connected"; then
    check "Job ddp has finished (the workers are connected and training, $(progress_msg ddp); about 30-60 s)" false
  else
    check "Job ddp has finished (the workers have not connected yet; kubectl logs -l batch.kubernetes.io/job-name=ddp --prefix)" false
  fi
  exit 1
fi
check_eq "Job ddp completed" complete "$st"
why "kubectl logs -l batch.kubernetes.io/job-name=ddp --prefix"
inspect_up results
m=/mnt/results/metrics.json
check_eq "metrics.json: the run finished with 2 workers" "done 300 2" "$(mget $m status step world_size | paste -sd' ' -)"
hosts="$(mget1 $m runs.-1.hosts | tr -d '[]" ' | tr ',' ' ')"
check "Both ranks ran in different pods (hosts: ${hosts:-?})" bash -c 'set -- $1; [[ $# -eq 2 && "$1" != "$2" ]]' _ "$hosts"
loss="$(mget1 $m loss)"
check "The final loss is below 2.9 (got ${loss:-?})" float_lt "$loss" 2.9
inspect_down
