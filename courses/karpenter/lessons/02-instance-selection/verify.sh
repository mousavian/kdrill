source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=apps
NP=nodepool/general
req() { jp $NP "{.spec.template.spec.requirements[?(@.key==\"$1\")].operator} {.spec.template.spec.requirements[?(@.key==\"$1\")].values[*]}"; }

echo "NodePool general"
check_eq "No longer pins node.kubernetes.io/instance-type" "" "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="node.kubernetes.io/instance-type")].key}')"
why "Those m5 types don't exist in this cloud (kubectl -n karpenter get cm instance-types -o jsonpath='{.data.catalog\.txt}'). Describe the shape you want instead of listing types."
check_eq "Requires kubernetes.io/arch In [arm64]" "In arm64" "$(req kubernetes.io/arch)"
check_eq "Requires karpenter.k8s.aws/instance-category In [m]" "In m" "$(req karpenter.k8s.aws/instance-category)"
op="$(jp $NP '{.spec.template.spec.requirements[?(@.key=="karpenter.kwok.sh/instance-cpu")].operator}')"
check "Sets a minimum size on karpenter.kwok.sh/instance-cpu (Gt or Gte)" bash -c '[[ "$1" == Gt || "$1" == Gte ]]' _ "$op"
check_eq "Still on-demand only" "In on-demand" "$(req karpenter.sh/capacity-type)"
check_eq "Still limited to 64 CPUs" 64 "$(jp $NP '{.spec.limits.cpu}')"

echo "Fleet"
check_eq "api: 6 pods Running" 6 "$(live_running $NS app=api)"
why "Still Pending? kubectl -n $NS describe pod -l app=api shows Karpenter's reason (FailedScheduling from karpenter)."
check_eq "worker: 1 pod Running" 1 "$(live_running $NS app=worker)"
check_eq "Every node is arm64" arm64 "$(karp_node_labels kubernetes.io/arch)"
check_eq "Every node is general purpose (instance-category m)" m "$(karp_node_labels karpenter.k8s.aws/instance-category)"
small="$(karp_node_labels karpenter.kwok.sh/instance-cpu | tr ' ' '\n' | awk '$1+0 < 4' | paste -sd' ' -)"
check_eq "No node has fewer than 4 vCPUs" "" "$small"
why "Nodes launched before you fixed the pool stay until something removes them: kubectl delete nodeclaim <name>"
check_eq "Every node is from NodePool general" general "$(karp_node_labels karpenter.sh/nodepool)"

echo "guards"
check_workload_unchanged deploy/api $NS api
check_workload_unchanged deploy/worker $NS worker
check_eq "Workloads don't pin nodes (no nodeSelector / affinity)" "" \
  "$(jp deploy/api '{.spec.template.spec.nodeSelector}{.spec.template.spec.affinity}' -n $NS)$(jp deploy/worker '{.spec.template.spec.nodeSelector}{.spec.template.spec.affinity}' -n $NS)"
why "This lesson is about the NodePool: the pods should run on whatever it launches."
check_only_karpenter_nodes
check_karpenter_up
