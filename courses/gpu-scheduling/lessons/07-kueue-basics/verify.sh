source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
NS=ml-team

check_eq "ResourceFlavor a100 targets nodes labelled nvidia.com/gpu.product=NVIDIA-A100-SXM4-80GB" NVIDIA-A100-SXM4-80GB \
  "$(jp resourceflavor/a100 '{.spec.nodeLabels.nvidia\.com/gpu\.product}')"
why "spec.nodeLabels: {nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB}"
check_eq "ClusterQueue ml-cq has a quota of 8 nvidia.com/gpu in flavor a100" 8 \
  "$(jp clusterqueue/ml-cq '{.spec.resourceGroups[*].flavors[?(@.name=="a100")].resources[?(@.name=="nvidia.com/gpu")].nominalQuota}')"
check_eq "ClusterQueue ml-cq has no cohort (no borrowing yet)" "" "$(jp clusterqueue/ml-cq '{.spec.cohortName}')"
check_eq "LocalQueue ml-team (namespace ml-team) points to ml-cq" ml-cq "$(jp localqueue/ml-team '{.spec.clusterQueue}' -n $NS)"
why "The Jobs are labelled kueue.x-k8s.io/queue-name: ml-team, so that LocalQueue must exist in their namespace."

jobs="$(kubectl -n $NS get jobs -l kueue.x-k8s.io/queue-name=ml-team -o name 2>/dev/null | sort | paste -sd' ' -)"
check_eq "The 3 training Jobs still exist, labelled for queue ml-team" "job.batch/train-1 job.batch/train-2 job.batch/train-3" "$jobs"
why "Don't delete Jobs; Kueue should decide which run now and which wait. (kdrill reset restores them.)"
shape=""
for j in train-1 train-2 train-3; do shape+="$(jp job/$j '{.spec.parallelism}' -n $NS)x$(jp job/$j '{.spec.template.spec.containers[0].resources.limits.nvidia\.com/gpu}' -n $NS) "; done
check_eq "Each Job still runs 2 pods with 2 GPUs each" "2x2 2x2 2x2" "${shape% }"

adm=0; pend=0; partial=""; bad=""
for j in train-1 train-2 train-3; do
  s="$(wl_state $NS $j)"; r="$(job_running $j $NS)"; p="$(job_pods $j $NS)"
  case "$s" in
    admitted) adm=$((adm+1)); [[ "$r" == 2 ]] || partial+="$j($r/2) " ;;
    pending)  pend=$((pend+1)); [[ "$p" == 0 && "$(jp job/$j '{.spec.suspend}' -n $NS)" == true ]] || bad+="$j " ;;
  esac
done
check_eq "Kueue admitted exactly 2 Jobs (8 GPUs of quota)" 2 "$adm"
why "kubectl -n $NS get workloads; kubectl -n $NS describe workload <name>. Common causes: missing LocalQueue, ClusterQueue namespaceSelector left empty (null = no namespaces), cpu/memory not in coveredResources."
check_eq "Exactly 1 Job is still queued" 1 "$pend"
check_eq "Admitted Jobs have both pods Running" "" "$partial"
check_eq "The queued Job stays suspended with no pods" "" "$bad"
check "Every Running training pod is on an A100 node" pods_on_nodes_with batch.kubernetes.io/job-name nvidia.com/gpu.product=NVIDIA-A100-SXM4-80GB
why "The ResourceFlavor's nodeLabels are injected into admitted pods as a nodeSelector."
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 3 nodes" 3 "$(fake_node_count)"
check_fleet_unchanged
