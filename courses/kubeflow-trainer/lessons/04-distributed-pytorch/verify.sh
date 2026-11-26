source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=tiny-ddp; T=ddp
check "The runtime $RT has the PyTorch policy (mlPolicy.torch)" bash -c '[[ -n "$(kubectl get '$CTR' '$RT' -o jsonpath="{.spec.mlPolicy.torch}" 2>/dev/null)" ]]'
why "Without a framework policy the controller injects no PET_* variables. kubectl explain clustertrainingruntime.spec.mlPolicy"
check "TrainJob $T exists with numNodes 2" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.spec.trainer.numNodes}")" == 2 ]]'
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
check_eq "One Indexed Job with 2 pods (completions 2, parallelism 2)" "Indexed 2 2" "$(jp job/$T-node-0 '{.spec.completionMode} {.spec.completions} {.spec.parallelism}')"
pods="$(tj_pods_of $T node)"
check_eq "Two node pods" 2 "$(echo "$pods" | grep -c .)"
ok=1; bad=""
for p in $pods; do
  v="$(pod_env $p PET_NNODES) $(pod_env $p PET_MASTER_ADDR) $(pod_env $p PET_MASTER_PORT) $(pod_env_field $p PET_NODE_RANK)"
  [[ "$v" == "2 ddp-node-0-0.ddp 29500 metadata.annotations['batch.kubernetes.io/job-completion-index']" ]] || { ok=0; bad="$p: $v"; }
done
check "The controller injected PET_NNODES=2, PET_MASTER_ADDR=ddp-node-0-0.ddp, PET_MASTER_PORT=29500 and PET_NODE_RANK (from the Job completion index) in both pods ${bad:+(got $bad)}" test $ok = 1
why "These come from mlPolicy.torch, not from the TrainJob. Recreate the TrainJob after fixing the runtime (it keeps a snapshot)."
p0="$(echo "$pods" | head -n 1)"
check_eq "The container is started with torchrun" torchrun "$(jp pod/${p0:-none} '{.spec.containers[0].command[0]}')"
fail_fast
if ! wait_tj $T 90; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
for i in 0 1; do
  l="$(tj_node_logs $T $i)"
  check "Node $i logs 'rank $i/2' and 'all 2 workers connected'" bash -c 'grep -q "rank '$i'/2" <<<"$1" && grep -q "all 2 workers connected" <<<"$1" && grep -q "done: step 300" <<<"$1"' _ "$l"
  why "Each pod must join the same group: torchrun script, PET_* from the policy."
done
