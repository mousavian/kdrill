source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=shop
NP='nodepool/default'

check_eq "NodePool default exists" default "$(jp $NP '{.metadata.name}')"
why "kubectl get nodepools. Karpenter only launches nodes from a NodePool."
check_eq "It uses the KWOKNodeClass default (group karpenter.kwok.sh)" "karpenter.kwok.sh/KWOKNodeClass/default" \
  "$(jp $NP '{.spec.template.spec.nodeClassRef.group}/{.spec.template.spec.nodeClassRef.kind}/{.spec.template.spec.nodeClassRef.name}')"
check_eq "It requires kubernetes.io/arch In [amd64]" "In amd64" \
  "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="kubernetes.io/arch")].operator} {.spec.template.spec.requirements[?(@.key=="kubernetes.io/arch")].values[*]}')"
check_eq "It requires karpenter.sh/capacity-type In [on-demand]" "In on-demand" \
  "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].operator} {.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].values[*]}')"
check_eq "It is limited to 32 CPUs" 32 "$(jp $NP '{.spec.limits.cpu}')"
check_eq "NodePool default is Ready" True "$(jp $NP '{.status.conditions[?(@.type=="Ready")].status}')"
why "kubectl describe nodepool default (Conditions). A wrong nodeClassRef makes it NotReady."

check_eq "web: 4 pods Running" 4 "$(live_running $NS app=web)"
why "kubectl get nodeclaims; kubectl -n $KARP_NS logs deploy/karpenter | tail"
check_eq "web pods run on nodes launched from NodePool default" default "$(pod_node_labels $NS app=web karpenter.sh/nodepool)"
check_eq "Karpenter's nodes are amd64" amd64 "$(karp_node_labels kubernetes.io/arch)"
check_eq "Karpenter's nodes are on-demand" on-demand "$(karp_node_labels karpenter.sh/capacity-type)"

actual="$(pod_node_labels $NS app=web node.kubernetes.io/instance-type)"
check_eq "ConfigMap findings records the instance type Karpenter chose for web" "${actual:-<web not running>}" \
  "$(jp configmap/findings '{.data.instance-type}' -n $NS)"
why "kubectl get nodeclaims shows it in the TYPE column; then: kubectl -n $NS create configmap findings --from-literal=instance-type=<TYPE>"

echo "guards"
check_workload_unchanged deploy/web $NS web
check_only_karpenter_nodes
check_karpenter_up
