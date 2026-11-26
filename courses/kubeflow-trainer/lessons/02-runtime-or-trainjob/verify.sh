source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=team-tiny; T=team-run
check_eq "The platform's ClusterTrainingRuntime tiny-gpt is unchanged" "$(baseline_get platform)" "$(jp $CTR/tiny-gpt '{.spec}' | cksum | cut -d' ' -f1)"
why "Do not edit the platform's runtime: the team writes its own."

check "TrainingRuntime $RT exists in namespace $KDRILL_NS" kubectl get $TR $RT
why "kind: TrainingRuntime, in the same namespace as the TrainJob."
kubectl get $TR $RT >/dev/null 2>&1 || exit 1
check_eq "The runtime's replicated job node carries the ancestor label" trainer \
  "$(jp $TR/$RT '{.spec.template.spec.replicatedJobs[?(@.name=="node")].template.metadata.labels.trainer\.kubeflow\.org/trainjob-ancestor-step}')"

check "TrainJob $T exists" kubectl get $TJ $T
why "A TrainJob that names a runtime of the wrong kind is refused at admission. Check runtimeRef.kind."
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check_eq "TrainJob uses TrainingRuntime $RT" "TrainingRuntime $RT" "$(jp $TJ/$T '{.spec.runtimeRef.kind} {.spec.runtimeRef.name}')"
check_eq "The TrainJob stays small: no image, command or args of its own" "" "$(jp $TJ/$T '{.spec.trainer.image}{.spec.trainer.command}{.spec.trainer.args}')"
why "Those belong to the runtime; the TrainJob only adds the team's own settings."
check "The TrainJob sets RUN_TEAM=research" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.spec.trainer.env[?(@.name==\"RUN_TEAM\")].value}")" == research ]]'
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T

fail_fast
if ! wait_tj $T 60; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
pod="$(tj_pods $T | head -n 1)"
check_eq "The pod got RUN_TEAM=research from the TrainJob" research "$(pod_env "${pod:-none}" RUN_TEAM)"
logs="$(tj_logs $T node)"
check "The log shows the team's defaults from the runtime: 150 steps, seed 7" bash -c 'grep -q "steps=150" <<<"$1" && grep -q "seed=7" <<<"$1" && grep -q "done: step 150" <<<"$1"' _ "$logs"
