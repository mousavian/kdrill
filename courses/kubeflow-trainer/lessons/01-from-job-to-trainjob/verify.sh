source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=tiny-gpt; T=tiny

check "ClusterTrainingRuntime $RT exists" kubectl get $CTR $RT
why "A TrainJob names a runtime; the runtime does not exist yet. Write it from tiny-job's pod template."
kubectl get $CTR $RT >/dev/null 2>&1 || exit 1
anc="$(jp $CTR/$RT '{.spec.template.spec.replicatedJobs[?(@.name=="node")].template.metadata.labels.trainer\.kubeflow\.org/trainjob-ancestor-step}')"
check_eq "The replicated job node carries the ancestor label (trainer.kubeflow.org/trainjob-ancestor-step)" trainer "$anc"
why "Without it the controller does not know which step spec.trainer applies to."
check_eq "The runtime's container is called node and runs the ml-tiny image with train" "node kdrill.local/ml-tiny:0.1.0 train" \
  "$(jp $CTR/$RT '{.spec.template.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].name} {.spec.template.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].image} {.spec.template.spec.replicatedJobs[?(@.name=="node")].template.spec.template.spec.containers[0].command[0]}')"

check "TrainJob $T exists" kubectl get $TJ $T
why "kubectl apply -f manifests/trainjob.yaml"
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check_eq "TrainJob $T uses runtime $RT" "$RT" "$(jp $TJ/$T '{.spec.runtimeRef.name}')"
check "The JobSet $T is owned by the TrainJob (not created by hand)" tj_owns_jobset $T
why "The Trainer controller must create the JobSet; delete a hand-made one and let the TrainJob do it."
check_eq "The JobSet has one Job (tiny-node-0)" tiny-node-0 "$(kubectl get jobs -l jobset.sigs.k8s.io/jobset-name=$T -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)"
pod="$(tj_pods $T | head -n 1)"
check_eq "The pod runs kdrill.local/ml-tiny:0.1.0" kdrill.local/ml-tiny:0.1.0 "$(jp pod/${pod:-none} '{.spec.containers[0].image}')"

fail_fast
if ! wait_tj $T 60; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
why "kubectl describe trainjob $T; kubectl logs -l jobset.sigs.k8s.io/jobset-name=$T"
logs="$(tj_logs $T node)"
check "The log shows 200 steps and seed 3" bash -c 'grep -q "steps=200" <<<"$1" && grep -q "seed=3" <<<"$1" && grep -q "done: step 200" <<<"$1"' _ "$logs"
wait_job tiny-job 60 || true
tl="$(final_loss "$logs")"; jl="$(final_loss "$(kubectl logs job/tiny-job 2>/dev/null)")"
check "The final loss ($tl) matches the Job's ($jl) within 0.05: same training, now run by Trainer" bash -c 'awk -v a="$1" -v b="$2" "BEGIN{d=a-b; if(d<0)d=-d; exit !(a!=\"\" && b!=\"\" && d<0.05)}"' _ "$tl" "$jl"
