# Helpers for the kubeflow-trainer course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
# common.sh (check, jp, wait_until, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# It builds on the training-platform helpers (ML_IMAGE, lesson_prep, inspect_up and
# mget for reading checkpoint volumes, evict, Kueue helpers, ...): the TrainJobs here run
# the same tiny GPT in the same image, kdrill.local/ml-tiny.
source "$KDRILL_HOME/courses/training-platform/lib.sh"

KT_DIR="$KDRILL_HOME/courses/kubeflow-trainer"
TJ=trainjob.trainer.kubeflow.org
CTR=clustertrainingruntime.trainer.kubeflow.org
TR=trainingruntime.trainer.kubeflow.org

# --------------------------------------------------------------- TrainJob ----
# tj_cond TRAINJOB TYPE -> "True"/"False" for a condition (Complete, Failed, Suspended)
tj_cond() { jp "$TJ/$1" "{.status.conditions[?(@.type==\"$2\")].status}"; }
# tj_reason TRAINJOB TYPE -> the condition's reason
tj_reason() { jp "$TJ/$1" "{.status.conditions[?(@.type==\"$2\")].reason}"; }
# tj_state TRAINJOB -> missing | complete | failed | suspended | running | pending
tj_state() {
  if ! kubectl get "$TJ" "$1" >/dev/null 2>&1; then echo missing; return; fi
  [[ "$(tj_cond "$1" Complete)" == True ]] && { echo complete; return; }
  [[ "$(tj_cond "$1" Failed)" == True ]] && { echo failed; return; }
  [[ "$(tj_cond "$1" Suspended)" == True ]] && { echo suspended; return; }
  if [[ "$(jp "$TJ/$1" '{range .status.jobsStatus[*]}{.active}{" "}{end}')" =~ [1-9] ]]; then echo running; return; fi
  echo pending
}
# tj_pods TRAINJOB -> pod names of the TrainJob's JobSet, oldest first
tj_pods() {
  kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=$1" --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}
# tj_pods_of TRAINJOB REPLICATEDJOB -> pods of one replicated job (node, dataset-initializer, ...)
tj_pods_of() {
  kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=$1,jobset.sigs.k8s.io/replicatedjob-name=$2" --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}
# tj_logs TRAINJOB [REPLICATEDJOB] -> logs of every pod (oldest first), with the pod name as a prefix of each pod's block
tj_logs() {
  local p
  for p in $( if [[ -n "${2:-}" ]]; then tj_pods_of "$1" "$2"; else tj_pods "$1"; fi ); do
    kubectl logs "$p" 2>/dev/null
  done
}
# tj_node_logs TRAINJOB INDEX -> logs of the node pod with that job-completion index
tj_node_logs() {
  local p
  p="$(kubectl get pods -l "jobset.sigs.k8s.io/jobset-name=$1,jobset.sigs.k8s.io/replicatedjob-name=node,batch.kubernetes.io/job-completion-index=$2" \
        --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | tail -n 1)"
  [[ -n "$p" ]] && kubectl logs "$p" 2>/dev/null
}
# tj_owns_jobset TRAINJOB -> success when JobSet TRAINJOB is controlled by the TrainJob (not hand-made)
tj_owns_jobset() {
  [[ "$(jp "jobset.jobset.x-k8s.io/$1" '{.metadata.ownerReferences[?(@.controller==true)].kind}')" == TrainJob ]]
}
# wait_tj TRAINJOB SECONDS -> poll until the TrainJob is complete or failed
wait_tj() {
  local end=$((SECONDS + $2)) s
  while (( SECONDS < end )); do
    s="$(tj_state "$1")"
    [[ "$s" == complete || "$s" == failed ]] && return 0
    sleep 2
  done
  return 1
}
# tj_progress TRAINJOB -> "at step N" from the newest log line, or the state
tj_progress() {
  local s
  s="$(tj_logs "$1" node | sed -n 's/.* step \([0-9]*\/[0-9]*\) loss.*/\1/p' | tail -n 1)"
  if [[ -n "$s" ]]; then echo "at step $s"; else echo "$(tj_state "$1")"; fi
}
# tj_container_env TRAINJOB NAME -> value of an env var in the JobSet's node container (what the pods really get)
js_node_env() {
  jp "jobset.jobset.x-k8s.io/$1" "{.spec.replicatedJobs[?(@.name==\"node\")].template.spec.template.spec.containers[?(@.name==\"node\")].env[?(@.name==\"$2\")].value}"
}
# pod_env POD NAME -> literal value of an env var in the pod's first container
pod_env() { jp "pod/$1" "{.spec.containers[0].env[?(@.name==\"$2\")].value}"; }

# Runtimes are cluster-scoped: lesson cleanup removes every (Cluster)TrainingRuntime, since the
# course installs none of the stock ones and learners create their own.
trainer_cleanup() {
  kubectl delete "$TJ" --all -n "$KDRILL_NS" --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  kubectl delete "$TR" --all -n "$KDRILL_NS" --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  kubectl delete "$CTR" --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  return 0
}

# fail_fast - stop verify here when a check above has already failed (do not make the learner wait
# for a training run that cannot be the right one)
fail_fast() { if (( _KD_FAIL > 0 )); then exit 1; fi; return 0; }
# pod_env_field POD NAME -> fieldPath of an env var that comes from the downward API
pod_env_field() { jp "pod/$1" "{.spec.containers[0].env[?(@.name==\"$2\")].valueFrom.fieldRef.fieldPath}"; }
# rt_job RESOURCE JOBNAME SUBPATH -> a field of replicated job JOBNAME in a (Cluster)TrainingRuntime,
# e.g.  rt_job $CTR/tiny-gpt node .template.spec.template.spec.containers[0].image
rt_job() {
  jp "$1" "{.spec.template.spec.replicatedJobs[?(@.name==\"$2\")]$3}"
}
