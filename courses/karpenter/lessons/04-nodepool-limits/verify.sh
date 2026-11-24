source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=web
NP=nodepool/default

echo "NodePool default"
check_eq "limits: cpu 16, memory 64Gi, nvidia.com/gpu 0" "16 64Gi 0" \
  "$(jp $NP '{.spec.limits.cpu} {.spec.limits.memory} {.spec.limits.nvidia\.com/gpu}')"
why "kubectl explain nodepool.spec.limits. Any resource name works, including extended resources like nvidia.com/gpu."
check_eq "Requirements unchanged (amd64, on-demand)" "amd64 on-demand" \
  "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="kubernetes.io/arch")].values[*]} {.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].values[*]}')"
why "Fix this with limits; leave the requirements alone."

echo "Fleet"
check_eq "web: 6 pods Running" 6 "$(live_running $NS app=web)"
why "kubectl -n $NS describe pod -l app=web | grep karpenter; kubectl get nodepool default -o jsonpath='{.status.resources}'"
check_eq "ml-batch is Pending (it may not get a GPU node from this pool)" "0 1" \
  "$(live_running $NS app=ml-batch) $(live_pending $NS app=ml-batch)"
check_eq "No GPU nodes in the fleet" 0 "$(karp_node_count karpenter.k8s.aws/instance-gpu-name)"
why "Limits only stop new launches; a GPU node that already exists stays. Remove it: kubectl delete nodeclaim <name>"
cpu="$(karp_capacity cpu karpenter.sh/nodepool=default)"
check "The pool's nodes have at most 16 CPUs in total (now: $cpu)" awk -v c="$cpu" 'BEGIN{exit !(c <= 16)}'

echo "guards"
check_workload_unchanged deploy/web $NS web
check_workload_unchanged deploy/ml-batch $NS ml
check_only_karpenter_nodes
check_karpenter_up
