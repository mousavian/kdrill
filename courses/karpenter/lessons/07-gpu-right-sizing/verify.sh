source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=ai
GN=karpenter.k8s.aws/instance-gpu-name

echo "Workloads"
check_eq "chat: 3 pods Running, on L4 GPUs" "3 l4" "$(live_running $NS app=chat) $(pod_node_labels $NS app=chat $GN)"
why "kubectl -n $NS describe pod -l app=chat | tail -3. nvidia.com/gpu.product is set by GPU feature discovery after a node boots; Karpenter can't launch for it."
check_eq "eval: Running on a 24 GB GPU (l4 or a10g)" yes \
  "$( [[ "$(live_running $NS app=eval)" == 1 ]] && [[ " l4 a10g " == *" $(pod_node_labels $NS app=eval $GN) "* ]] && echo yes)"
why "Now on: $(pod_node_labels $NS app=eval node.kubernetes.io/instance-type)"
check_eq "train: Running on an 8 x H100 node" "1 h100 8" \
  "$(live_running $NS app=train) $(pod_node_labels $NS app=train $GN) $(pod_node_labels $NS app=train karpenter.k8s.aws/instance-gpu-count)"

echo "Cost"
idle="$(idle_gpus)"
check_eq "No idle GPUs in the fleet" 0 "$idle"
why "$idle GPU(s) paid for but unused. kubectl get nodes -L node.kubernetes.io/instance-type,$GN,karpenter.k8s.aws/instance-gpu-count; kubectl describe node <n> | grep -A6 Allocated. An empty node is removed by consolidation ~15 s after it empties."
price="$(kubectl get nodes -l "karpenter.sh/nodepool,$GN" --no-headers -o custom-columns=P:.metadata.labels.eks-node-viewer/instance-price,DEL:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{s+=$1} END{printf "%.2f", s}')"
check "The GPU fleet costs at most \$59.00/h (now: \$$price/h)" awk -v p="$price" 'BEGIN{exit !(p <= 59.00)}'
why "Per-node prices: kubectl get nodes -L node.kubernetes.io/instance-type,eks-node-viewer/instance-price"

echo "guards"
check_pool_unchanged gpu gpu
check_workload_unchanged deploy/chat $NS chat
check_workload_unchanged deploy/eval $NS eval
check_workload_unchanged deploy/train $NS train
check_eq "train's pod spec is unchanged" "$(baseline_get trainspec)" "$(kubectl -n $NS get deploy train -o jsonpath='{.spec.template.spec}')"
check_only_karpenter_nodes
check_karpenter_up
