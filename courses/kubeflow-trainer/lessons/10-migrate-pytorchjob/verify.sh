source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
T=tiny-pytorchjob
check_eq "The platform's runtime tiny-ddp is unchanged" "$(baseline_get platform)" "$(jp $CTR/tiny-ddp '{.spec}' | cksum | cut -d' ' -f1)"
check "The Training Operator's PyTorchJob CRD is not installed (this is a migration, not an install)" bash -c '! kubectl get crd pytorchjobs.kubeflow.org >/dev/null 2>&1'
check "TrainJob $T exists and uses tiny-ddp" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.spec.runtimeRef.name}")" == tiny-ddp ]]'
why "Write manifests of kind TrainJob (trainer.kubeflow.org/v1alpha1) for the runtime tiny-ddp."
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check_eq "numNodes is 2 (Master 1 + Worker 1)" 2 "$(jp $TJ/$T '{.spec.trainer.numNodes}')"
args="$(jp $TJ/$T '{.spec.trainer.args}')"
check "The old options are in spec.trainer.args (got: $args)" bash -c '[[ "$1" == *\"--steps\",\"400\"* && "$1" == *\"--seed\",\"5\"* && "$1" == *\"--batch-size\",\"16\"* ]]' _ "$args"
check_eq "The old command (train) was not copied into the TrainJob" "" "$(jp $TJ/$T '{.spec.trainer.command}')"
why "The runtime launches torchrun; the old command's options are the arguments."
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
pods="$(tj_pods_of $T node)"
check_eq "Two node pods" 2 "$(echo "$pods" | grep -c .)"
p0="$(echo "$pods" | head -n 1)"
c='{.spec.containers[0]'
check_eq "Each pod: RUN_NAME=legacy-migration, requests 500m/450Mi, memory limit 1Gi, started with torchrun" \
  "legacy-migration 500m 450Mi 1Gi torchrun" \
  "$(pod_env "${p0:-none}" RUN_NAME) $(jp pod/${p0:-none} "$c.resources.requests.cpu} $c.resources.requests.memory} $c.resources.limits.memory} $c.command[0]}")"
check_eq "The controller injected PET_NNODES=2 (the old WORLD_SIZE) and PET_MASTER_ADDR" "2 $T-node-0-0.$T" "$(pod_env "${p0:-none}" PET_NNODES) $(pod_env "${p0:-none}" PET_MASTER_ADDR)"
fail_fast
if ! wait_tj $T 90; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
for i in 0 1; do
  l="$(tj_node_logs $T $i)"
  check "Node $i is rank $i of 2: all workers connected, 400 steps, seed 5, batch size 16" bash -c 'grep -q "rank '$i'/2" <<<"$1" && grep -q "all 2 workers connected" <<<"$1" && grep -q "steps=400" <<<"$1" && grep -q "seed=5" <<<"$1" && grep -q "batch_size=16" <<<"$1" && grep -q "done: step 400" <<<"$1"' _ "$l"
done
