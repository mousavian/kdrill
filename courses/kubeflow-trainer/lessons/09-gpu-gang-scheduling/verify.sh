source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
check_eq "ClusterQueue training-cq is unchanged (4 GPUs)" "$(baseline_get quota)" "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
check_eq "The runtime gpu-ddp is unchanged" "$(baseline_get runtime)" "$(jp $CTR/gpu-ddp '{.spec}' | cksum | cut -d' ' -f1)"
check_eq "The two fake GPU nodes are still there" 2 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"

adm=""; pend=""; partial=""; bad=""
for j in llama mistral; do
  if ! kubectl get $TJ $j >/dev/null 2>&1; then check "TrainJob $j exists" false; continue; fi
  check_eq "$j is submitted to the queue training and still asks for 2 nodes" "training 2" \
    "$(jp $TJ/$j '{.metadata.labels.kueue\.x-k8s\.io/queue-name} {.spec.trainer.numNodes}')"
  why "Create it with the label kueue.x-k8s.io/queue-name=training (delete the running TrainJob first)."
  w="$(wl_of TrainJob $j)"
  n="$(tj_pods $j | grep -c .)"; r="$(running_count jobset.sigs.k8s.io/jobset-name=$j)"
  if [[ -n "$w" && "$(wl_cond "$w" Admitted)" == True && "$r" == 2 ]]; then
    adm+="$j "
    nodes="$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=$j -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | grep -c .)"
    [[ "$nodes" == 2 ]] || bad+="$j(pods on $nodes node(s)) "
    for p in $(tj_pods $j); do
      [[ "$(jp pod/$p '{.spec.containers[0].resources.limits.nvidia\.com/gpu}') $(pod_env $p PET_NPROC_PER_NODE)" == "2 auto" ]] || bad+="$p(GPU limit or PET_NPROC_PER_NODE) "
    done
  elif [[ -n "$w" && "$(wl_cond "$w" Admitted)" != True && "$n" == 0 && "$(tj_state $j)" == suspended ]]; then
    pend+="$j "
  fi
  (( n > 0 && r < 2 )) && partial+="$j($r/2 running) "
done
check_eq "One TrainJob is admitted and runs on both nodes (2 pods Running)" 1 "$(echo $adm | wc -w | tr -d ' ')"
why "kubectl get workloads; kubectl get pods -o wide"
check_eq "Its two pods are on two different nodes with 2 GPUs each and PET_NPROC_PER_NODE=auto ${bad:+(problem: $bad)}" "" "$bad"
check_eq "The other TrainJob waits in the queue: suspended, no pods, no GPUs held" 1 "$(echo $pend | wc -w | tr -d ' ')"
check_eq "No TrainJob is running with only some of its nodes" "" "${partial% }"
why "That is the deadlock: partially started jobs hold GPUs and make no progress."
all_on_fake() {
  local j
  for j in llama mistral; do
    [[ -z "$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=$j -o name)" ]] && continue
    pods_on_nodes_with jobset.sigs.k8s.io/jobset-name=$j type=kwok || return 1
  done
}
check "Every pod is on a simulated node" all_on_fake
