source "$KDRILL_HOME/courses/training-platform/lib.sh"
js=jobset.jobset.x-k8s.io/capstone
check_eq "ClusterQueue training-cq is unchanged" "$(baseline_get quota)" "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
check "JobSet capstone exists" kubectl get $js
kubectl get $js >/dev/null 2>&1 || exit 1
c='{.spec.replicatedJobs[0].template.spec.template.spec.containers[0]'
envv() { jp $js "$c.env[?(@.name==\"$1\")].value}"; }
check_eq "The planted fault is still there (FAIL_AT_STEP FAIL_RANK FAIL_ONCE FAIL_EXIT_CODE)" "300 1 true 1" \
  "$(envv FAIL_AT_STEP) $(envv FAIL_RANK) $(envv FAIL_ONCE) $(envv FAIL_EXIT_CODE)"
why "The crash stands for a flaky node; the setup must survive it, not avoid it."
check_eq "Two workers, 900 steps, child backoffLimit 0" "2 2 2 900 0" \
  "$(jp $js '{.spec.replicatedJobs[0].template.spec.completions} {.spec.replicatedJobs[0].template.spec.parallelism}') $(envv WORLD_SIZE) $(envv STEPS) $(jp $js '{.spec.replicatedJobs[0].template.spec.backoffLimit}')"
check_eq "Each worker still requests 1 CPU" 1 "$(jp $js "$c.resources.requests.cpu}")"
check_eq "The JobSet goes through the queue training" training "$(jp $js '{.metadata.labels.kueue\.x-k8s\.io/queue-name}')"
w="$(wl_of JobSet capstone)"
check "It has a Kueue Workload" test -n "$w"
mr="$(jp $js '{.spec.failurePolicy.maxRestarts}')"
check "A worker crash restarts the set (failurePolicy.maxRestarts 1-5, got ${mr:-unset})" bash -c '[[ "$1" =~ ^[1-5]$ ]]' _ "$mr"
ck="$(jp $js "{.spec.replicatedJobs[0].template.spec.template.spec.volumes[?(@.name==\"$(jp $js "$c.volumeMounts[?(@.mountPath==\"$(envv CKPT_DIR)\")].name}")\")].persistentVolumeClaim.claimName}")"
check "Checkpoints (CKPT_DIR) are on the PVC checkpoints (got ${ck:-not a PVC})" test "$ck" = checkpoints
check_eq "The model is written to /models/capstone (MODEL_OUT)" /models/capstone "$(envv MODEL_OUT)"
done_="$(jp $js '{.status.conditions[?(@.type=="Completed")].status}')"
failed="$(jp $js '{.status.conditions[?(@.type=="Failed")].status}')"
if [[ "$done_" != True ]]; then
  if [[ "$failed" == True ]]; then
    check "JobSet capstone did not fail ($(jp $js '{.status.conditions[?(@.type=="Failed")].message}'))" false
  else
    check "JobSet capstone has completed (restarts so far: $(jp $js '{.status.restarts}'); about 1-2 minutes in all)" false
  fi
  exit 1
fi
check "JobSet capstone completed" true
check_ge "It survived the crash by restarting (status.restarts)" 1 "$(jp $js '{.status.restarts}')"
[[ -n "$w" ]] && check_eq "Its Workload was admitted and finished" "True True" "$(wl_cond "$w" Admitted) $(wl_cond "$w" Finished)"
inspect_up checkpoints models
m=/mnt/checkpoints/metrics.json
check_eq "The run finished on 2 workers (metrics.json status, step, world_size)" "done 900 2" "$(mget $m status step world_size | paste -sd' ' -)"
starts="$(mget1 $m runs | tr -d ' ' | grep -o '"start_step":[0-9]*' | cut -d: -f2 | paste -sd' ' -)"
check "After the crash the workers resumed from the checkpoint at step 300 (attempts started at: ${starts:-?})" \
  bash -c '[[ " $1 " == *" 300 "* ]]' _ "$starts"
check_eq "The model artifact exists (models/capstone/model.json: steps, world_size)" "900 2" "$(mget /mnt/models/capstone/model.json steps world_size | paste -sd' ' -)"
inspect_down
check "Job sample exists" kubectl get job sample
if kubectl get job sample >/dev/null 2>&1; then
  check_eq "Job sample completed" complete "$(job_state sample)"
  why "Run it after the JobSet has completed (kubectl delete job sample, then apply it again)."
  check "It sampled from /models/capstone/model.pt" bash -c '[[ "$1" == *"sample from /models/capstone/model.pt"* ]]' _ "$(job_logs sample)"
fi
