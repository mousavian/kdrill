source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
T=tuned
check_eq "The platform's ClusterTrainingRuntime tiny-gpt is unchanged" "$(baseline_get platform)" "$(jp $CTR/tiny-gpt '{.spec}' | cksum | cut -d' ' -f1)"
why "Override from the TrainJob; the runtime is the platform's."
check "TrainJob $T exists and uses tiny-gpt" bash -c '[[ "$(kubectl get '$TJ' '$T' -o jsonpath="{.spec.runtimeRef.name}")" == tiny-gpt ]]'
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
pod="$(tj_pods $T | tail -n 1)"
[[ -n "$pod" ]] || { check "The TrainJob has a pod" false; exit 1; }
c='{.spec.containers[0]'
check_eq "The pod still runs the runtime's image and command (kdrill.local/ml-tiny:0.1.0, train)" "kdrill.local/ml-tiny:0.1.0 train" "$(jp pod/$pod "$c.image} $c.command[0]}")"
check_eq "RUN_LABEL=lesson3 reaches the pod" lesson3 "$(pod_env "$pod" RUN_LABEL)"
check_eq "The runtime's OMP_NUM_THREADS=1 is still there (env is merged, not replaced)" 1 "$(pod_env "$pod" OMP_NUM_THREADS)"
check_eq "Requests: 500m CPU, 450Mi memory; memory limit 1Gi" "500m 450Mi 1Gi" "$(jp pod/$pod "$c.resources.requests.cpu} $c.resources.requests.memory} $c.resources.limits.memory}")"
why "spec.trainer.resourcesPerNode: requests and limits, merged over the runtime's."
args="$(jp pod/$pod "$c.args}")"
check "The pod's arguments ask for 300 steps, seed 11 and batch size 16 (got: $args)" bash -c '[[ "$1" == *\"--steps\",\"300\"* && "$1" == *\"--seed\",\"11\"* && "$1" == *\"--batch-size\",\"16\"* ]]' _ "$args"
why "A flag in the runtime's args beats an environment variable. spec.trainer.args replaces the runtime's args."

fail_fast
if ! wait_tj $T 75; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
logs="$(tj_logs $T node)"
check "The log confirms: 300 steps, seed 11, batch size 16" bash -c 'grep -q "steps=300" <<<"$1" && grep -q "seed=11" <<<"$1" && grep -q "batch_size=16" <<<"$1" && grep -q "done: step 300" <<<"$1"' _ "$logs"
