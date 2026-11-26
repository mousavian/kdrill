source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
RT=tiny-data; T=withdata
check_eq "The runtime has a volume claim template named initializer" initializer "$(jp $CTR/$RT '{.spec.template.spec.volumeClaimPolicies[*].templates[*].metadata.name}')"
why "volumeClaimPolicies in the runtime's JobSet spec: JobSet creates one PVC per TrainJob from it."
VM=.template.spec.template.spec.containers[0].volumeMounts[0]
check_eq "The dataset-initializer container mounts it at /workspace" "initializer:/workspace" \
  "$(rt_job $CTR/$RT dataset-initializer $VM.name):$(rt_job $CTR/$RT dataset-initializer $VM.mountPath)"
check_eq "The trainer container mounts it at /workspace" "initializer:/workspace" \
  "$(rt_job $CTR/$RT node $VM.name):$(rt_job $CTR/$RT node $VM.mountPath)"
why "The trainer reads /workspace/dataset; without the mount it sees an empty directory."

check "TrainJob $T exists" kubectl get $TJ $T
why "kubectl apply -f manifests/trainjob.yaml (the webhook validates it against the runtime)"
kubectl get $TJ $T >/dev/null 2>&1 || exit 1
check_eq "TrainJob asks for the dataset by URI" "file:///opt/ml-tiny/datasets/tinyshakespeare.txt.gz" "$(jp $TJ/$T '{.spec.initializer.dataset.storageUri}')"
check "The JobSet $T is owned by the TrainJob" tj_owns_jobset $T
check_eq "The trainer waits for the initializer (dependsOn dataset-initializer)" dataset-initializer "$(jp jobset/$T '{.spec.replicatedJobs[?(@.name=="node")].dependsOn[*].name}')"
fail_fast
if ! wait_tj $T 100; then
  check "TrainJob $T has completed (it is $(tj_state $T), $(tj_progress $T); verify again in a few seconds)" false
  exit 1
fi
check_eq "TrainJob $T is Complete" True "$(tj_cond $T Complete)"
ip="$(tj_pods_of $T dataset-initializer | head -n 1)"; np="$(tj_pods_of $T node | head -n 1)"
check_eq "The initializer got STORAGE_URI from the TrainJob" "file:///opt/ml-tiny/datasets/tinyshakespeare.txt.gz" "$(pod_env "${ip:-none}" STORAGE_URI)"
fin="$(jp pod/${ip:-none} '{.status.containerStatuses[0].state.terminated.finishedAt}')"
st="$(jp pod/${np:-none} '{.status.containerStatuses[0].state.terminated.startedAt}')"
check "The initializer finished ($fin) before the trainer started ($st)" bash -c '[[ -n "$1" && -n "$2" && ! "$2" < "$1" ]]' _ "$fin" "$st"
check "The initializer wrote /workspace/dataset/input.txt" bash -c 'grep -q "prepare: wrote /workspace/dataset/input.txt" <<<"$1"' _ "$(tj_logs $T dataset-initializer)"
logs="$(tj_logs $T node)"
check "The trainer read its data from /workspace/dataset and finished 200 steps" bash -c 'grep -q "data=/workspace/dataset" <<<"$1" && grep -q "done: step 200" <<<"$1"' _ "$logs"
