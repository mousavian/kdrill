source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "PVC checkpoints exists" kubectl get pvc checkpoints
modes="$(jp pvc/checkpoints '{.spec.accessModes[*]}')"
check "PVC checkpoints can be mounted by more than one pod (access modes: ${modes:-?})" bash -c '[[ -n "$1" && " $1 " != *" ReadWriteOncePod "* && " $1 " != " ReadOnlyMany " ]]' _ "$modes"
why "ReadWriteOncePod = one pod. The workers need ReadWriteOnce (one node) or ReadWriteMany (many nodes)."
check "Job ddp exists" kubectl get job ddp
kubectl get job ddp >/dev/null 2>&1 || exit 1
check_eq "Still two workers (Indexed, completions 2, parallelism 2, WORLD_SIZE 2)" "Indexed 2 2 2" \
  "$(jp job/ddp '{.spec.completionMode} {.spec.completions} {.spec.parallelism}') $(env_of job/ddp WORLD_SIZE)"
check_eq "Every worker mounts the PVC checkpoints at CKPT_DIR (/ckpt)" "checkpoints /ckpt" \
  "$(jp job/ddp '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}') $(env_of job/ddp CKPT_DIR)"
check_eq "STEPS 400 and CKPT_EVERY 100 are unchanged" "400 100" "$(env_of job/ddp STEPS) $(env_of job/ddp CKPT_EVERY)"
st="$(job_state ddp)"
if [[ "$st" == running || "$st" == pending ]]; then
  pend="$(kubectl get pods -l batch.kubernetes.io/job-name=ddp --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if (( pend > 0 )); then
    check "No worker is Pending ($pend Pending: kubectl describe pod ... | tail)" false
  else
    check "Job ddp has finished (both workers run, $(progress_msg ddp); about 30-60 s)" false
  fi
  exit 1
fi
check_eq "Job ddp completed" complete "$st"
inspect_up checkpoints
m=/mnt/checkpoints/metrics.json
check_eq "The run finished on 2 workers (metrics.json status, step, world_size)" "done 400 2" "$(mget $m status step world_size | paste -sd' ' -)"
check_eq "The newest checkpoint on the shared volume is from step 400" 400 "$(ix mlt ckpt /mnt/checkpoints)"
inspect_down
