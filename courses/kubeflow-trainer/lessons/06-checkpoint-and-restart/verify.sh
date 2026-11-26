source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=tiny-resume; T=flaky
mr="$(jp $CTR/$RT '{.spec.template.spec.failurePolicy.maxRestarts}')"
check "The runtime restarts the group after a failure: failurePolicy.maxRestarts is 1-5 (got ${mr:-unset})" bash -c '[[ "$1" =~ ^[1-5]$ ]]' _ "$mr"
why "kubectl explain clustertrainingruntime.spec.template.spec.failurePolicy"
check "TrainJob $T exists" kubectl get $TJ $T
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check "It is a new TrainJob (the failed one was deleted and recreated)" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.metadata.uid}")" != "$(kubectl -n '$KDRILL_NS' get cm kdrill-baseline -o jsonpath="{.data.uid}")" ]]'
why "spec.trainer and the runtime snapshot are fixed at creation: delete flaky and create it again."
check_eq "The planted fault and the run size are still there (FAIL_AT_STEP 300, FAIL_ONCE true, STEPS 800)" "300 true 800" \
  "$(js_node_env $T FAIL_AT_STEP) $(js_node_env $T FAIL_ONCE) $(js_node_env $T STEPS)"
check_eq "CKPT_DIR is /ckpt" /ckpt "$(js_node_env $T CKPT_DIR)"
js="jobset.jobset.x-k8s.io/$T"
check_eq "The pod mounts the PVC checkpoints at /ckpt" "checkpoints /ckpt" \
  "$(jp $js '{.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.volumes[*].persistentVolumeClaim.claimName} {.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].volumeMounts[*].mountPath}')"
why "Add the volume and the mount with spec.runtimePatches (replicated job node, container node)."
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
fail_fast
end=$((SECONDS + 100))
while (( SECONDS < end )); do s="$(tj_state $T)"; [[ "$s" == complete || "$s" == failed ]] && break; sleep 2; done
s="$(tj_state $T)"
if [[ "$s" != complete && "$s" != failed ]]; then
  check "TrainJob $T has finished (it is $s, $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T completed (it is $s)" True "$(tj_cond $T Complete)"
why "kubectl get trainjob $T -o jsonpath='{.status.conditions}'; a JobSet that cannot restart, or restarts without a checkpoint to resume from, ends Failed after crashing again."
check_ge "The JobSet restarted at least once (status.restarts)" 1 "$(jp $js '{.status.restarts}')"
inspect_up checkpoints
set -- $(mget /mnt/checkpoints/metrics.json len:runs runs.-1.start_step runs.0.start_step | paste -sd' ' -)
check "The second attempt resumed from a checkpoint: ${1:-?} attempts, the first started at ${3:-?}, the last at ${2:-?} (it must be 250 or later, not 0)" \
  bash -c '[[ "$1" == 2 && "$2" =~ ^[0-9]+$ && "$2" -ge 250 && "$3" == 0 ]]' _ "${1:-}" "${2:-}" "${3:-}"
why "Without the volume the replacement pod starts at step 0 and crashes at 300 again (the marker is lost too)."
inspect_down
