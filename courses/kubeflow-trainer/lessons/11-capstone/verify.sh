source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=capstone-ddp; T=final-run
js="jobset.jobset.x-k8s.io/$T"
check_eq "ClusterQueue team-cq is unchanged (2 CPU, 4Gi)" "$(baseline_get quota)" "$(jp clusterqueue.kueue.x-k8s.io/team-cq '{.spec.resourceGroups}')"
why "Fit the TrainJob into the queue; do not enlarge the queue."
check "PVC checkpoints exists" kubectl get pvc checkpoints

# --- the runtime (platform side)
check "The runtime has the PyTorch policy (mlPolicy.torch)" bash -c '[[ -n "$(kubectl get '$CTR' '$RT' -o jsonpath="{.spec.mlPolicy.torch}" 2>/dev/null)" ]]'
why "Without it no PET_* variables are injected: the nodes do not form a group."
mr="$(jp $CTR/$RT '{.spec.template.spec.failurePolicy.maxRestarts}')"
check "The runtime restarts the group after a failure: failurePolicy.maxRestarts is 1-5 (got ${mr:-unset})" bash -c '[[ "$1" =~ ^[1-5]$ ]]' _ "$mr"
check_eq "The runtime launches torchrun" torchrun "$(rt_job $CTR/$RT node .template.spec.template.spec.containers[0].command[0])"

# --- the TrainJob (user side)
check "TrainJob $T exists" kubectl get $TJ $T
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check "It is a new TrainJob (the old one was deleted and recreated)" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.metadata.uid}")" != "$(kubectl -n '$KDRILL_NS' get cm kdrill-baseline -o jsonpath="{.data.uid}")" ]]'
check_eq "The planted fault and the run are as before (FAIL_AT_STEP 300, FAIL_RANK 1, FAIL_ONCE true, 800 steps, 2 nodes)" "300 1 true 800 2" \
  "$(js_node_env $T FAIL_AT_STEP) $(js_node_env $T FAIL_RANK) $(js_node_env $T FAIL_ONCE) $(jp $TJ/$T '{.spec.trainer.args[1]}') $(jp $TJ/$T '{.spec.trainer.numNodes}')"
check_eq "The TrainJob is submitted to the queue team" team "$(jp $TJ/$T '{.metadata.labels.kueue\.x-k8s\.io/queue-name}')"
w="$(wl_of TrainJob $T)"
check "It has a Kueue Workload (owned by the TrainJob)" test -n "$w"
cpu="$(jp $js '{.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].resources.requests.cpu}')"
tot=$(( $(cpu_millis "${cpu:-0}") * $(jp $TJ/$T '{.spec.trainer.numNodes}') ))
check "The CPU request per node (${cpu:-?}) times 2 nodes fits the queue's 2 CPU (${tot}m)" bash -c '[[ "$1" -gt 0 && "$1" -le 2000 ]]' _ "$tot"
why "The runtime asks for 2 CPU per node; override resourcesPerNode in the TrainJob."
check_eq "The checkpoint volume is mounted: PVC checkpoints at /ckpt, CKPT_DIR=/ckpt" "checkpoints /ckpt /ckpt" \
  "$(jp $js '{.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.volumes[*].persistentVolumeClaim.claimName} {.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].volumeMounts[*].mountPath}') $(js_node_env $T CKPT_DIR)"
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
fail_fast
if [[ -n "$w" ]]; then check_eq "The Workload was admitted by Kueue" True "$(wl_cond "$w" Admitted)"; why "kubectl describe workload $w: is the request within the quota?"; fi

end=$((SECONDS + 110))
while (( SECONDS < end )); do s="$(tj_state $T)"; [[ "$s" == complete || "$s" == failed ]] && break; sleep 3; done
s="$(tj_state $T)"
if [[ "$s" != complete && "$s" != failed ]]; then
  check "TrainJob $T has finished (it is $s, $(tj_progress $T); verify again in a minute)" false
  exit 1
fi
check_eq "TrainJob $T completed (it is $s)" True "$(tj_cond $T Complete)"
why "kubectl get trainjob $T -o jsonpath='{.status.conditions}'"
check_ge "The JobSet restarted after the crash (status.restarts)" 1 "$(jp $js '{.status.restarts}')"
inspect_up checkpoints
set -- $(mget /mnt/checkpoints/metrics.json len:runs runs.-1.start_step runs.-1.world_size runs.0.start_step | paste -sd' ' -)
check "Two attempts; the last resumed from step ${2:-?} (not 0) with ${3:-?} workers (got ${1:-?} attempts)" \
  bash -c '[[ "$1" == 2 && "$2" =~ ^[0-9]+$ && "$2" -ge 250 && "$3" == 2 && "$4" == 0 ]]' _ "${1:-}" "${2:-}" "${3:-}" "${4:-}"
why "Without a volume the restarted group starts at step 0; as one group the world size is 2."
inspect_down
