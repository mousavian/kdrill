source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=ml
GP=nodepool/gpu

echo "NodePool gpu"
check_eq "gpu taints its nodes nvidia.com/gpu:NoSchedule" "nvidia.com/gpu NoSchedule" \
  "$(jp $GP '{.spec.template.spec.taints[?(@.key=="nvidia.com/gpu")].key} {.spec.template.spec.taints[?(@.key=="nvidia.com/gpu")].effect}')"
why "spec.template.spec.taints (not startupTaints: those are expected to be removed by a node agent, and nothing here removes them)."
check_eq "Every GPU node carries the taint" "" \
  "$(for n in $(karp_nodes karpenter.sh/nodepool=gpu); do jp node/$n '{.spec.taints[*].key}' | grep -qw nvidia.com/gpu || echo -n "$n "; done)"
why "Nodes launched before the change are drifted and replaced by Karpenter; give it ~30-60 s (kubectl get nodeclaims -w)."

echo "Workloads"
check_eq "inference tolerates nvidia.com/gpu" yes \
  "$(jp deploy/inference '{.spec.template.spec.tolerations[*].key}' -n $NS | grep -qw nvidia.com/gpu && echo yes)"
check_eq "inference: 2 pods Running on GPU-pool nodes" "2 gpu" "$(live_running $NS app=inference) $(pod_node_labels $NS app=inference karpenter.sh/nodepool)"
check_eq "web: 3 pods Running on general-pool nodes" "3 general" "$(live_running $NS app=web) $(pod_node_labels $NS app=web karpenter.sh/nodepool)"
why "kubectl -n $NS get pods -o wide. web pods on a GPU node leave when that node is replaced."
gpunodes=" $(karp_nodes karpenter.k8s.aws/instance-gpu-name | paste -sd' ' -) "
intruders="$(kubectl get pods -A --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name,NODE:.spec.nodeName,GPU:.spec.containers[*].resources.limits.nvidia\\.com/gpu,DEL:.metadata.deletionTimestamp 2>/dev/null \
  | awk -v g="$gpunodes" '$5=="<none>" && index(g, " "$3" ") && $4=="<none>" {printf "%s/%s ", $1, $2}')"
check_eq "Only GPU pods run on GPU nodes" "" "${intruders% }"

echo "guards"
check_pool_unchanged general general
check_eq "gpu keeps its requirements, limits and nodeClassRef" "$(baseline_get gpurest)" \
  "$(kubectl get nodepool gpu -o jsonpath='{.spec.template.spec.requirements}|{.spec.limits}|{.spec.template.spec.nodeClassRef}' 2>/dev/null)"
check_workload_unchanged deploy/web $NS web
check_workload_unchanged deploy/inference $NS inference
check_eq "web is not pinned (no nodeSelector / affinity)" "" "$(jp deploy/web '{.spec.template.spec.nodeSelector}{.spec.template.spec.affinity}' -n $NS)"
why "The taint alone should keep web off GPU nodes; that also protects them from the next workload someone forgets to pin."
check_only_karpenter_nodes
check_karpenter_up
