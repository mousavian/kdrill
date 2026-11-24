source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
NS=training

for j in llama-ft mistral-ft; do
  check_eq "$j exists and is submitted to queue training" training "$(jp job/$j '{.metadata.labels.kueue\.x-k8s\.io/queue-name}' -n $NS)"
  why "Label the Job kueue.x-k8s.io/queue-name=training when creating it (delete and re-create from solution/ or manifests/)."
  check_eq "$j still needs 4 workers at once (parallelism 4, completions 4, 1 GPU each)" "4 4 1" \
    "$(jp job/$j '{.spec.parallelism} {.spec.completions} {.spec.template.spec.containers[0].resources.limits.nvidia\.com/gpu}' -n $NS)"
done

adm=""; pend=""; partial=""
for j in llama-ft mistral-ft; do
  s="$(wl_state $NS $j)"; r="$(job_running $j $NS)"; p="$(job_pods $j $NS)"
  [[ "$s" == admitted && "$r" == 4 ]] && adm+="$j "
  [[ "$s" == pending && "$p" == 0 && "$(jp job/$j '{.spec.suspend}' -n $NS)" == true ]] && pend+="$j "
  (( p > 0 && r < 4 )) && partial+="$j($r/4 running) "
done
check_eq "One Job is admitted with all 4 workers Running" 1 "$(echo $adm | wc -w | tr -d ' ')"
why "kubectl get workloads; kubectl get pods -o wide"
check_eq "The other Job waits in the queue: suspended, no pods, no GPUs held" 1 "$(echo $pend | wc -w | tr -d ' ')"
check_eq "No Job is running with only some of its workers" "" "${partial% }"
why "That is the deadlock: partially started jobs hold GPUs and make no progress."
check_eq "ClusterQueue training-cq is unchanged (4 GPUs)" "$(kubectl -n "$KDRILL_NS" get cm kdrill-baseline -o jsonpath='{.data.extra}' 2>/dev/null)" "$(quotas)"
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged
