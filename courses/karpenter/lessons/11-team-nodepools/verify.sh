source "$KDRILL_HOME/courses/karpenter/lib.sh"

pool_checks() {  # pool_checks TEAM CAPACITY_TYPE
  local p="nodepool/$1"
  check_eq "NodePool $1 labels its nodes team=$1" "$1" "$(jp $p '{.spec.template.metadata.labels.team}')"
  check_eq "NodePool $1 taints its nodes team=$1:NoSchedule" "$1 NoSchedule" \
    "$(jp $p '{.spec.template.spec.taints[?(@.key=="team")].value} {.spec.template.spec.taints[?(@.key=="team")].effect}')"
  check_eq "NodePool $1 launches only $2 capacity" "In $2" \
    "$(jp $p '{.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].operator} {.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].values[*]}')"
  check_eq "NodePool $1 is limited to 16 CPUs" 16 "$(jp $p '{.spec.limits.cpu}')"
}
# intruders TEAM -> pods on that team's nodes that belong to another namespace
intruders() {
  local nodes
  nodes=" $(karp_nodes "team=$1" | paste -sd' ' -) "
  kubectl get pods -A --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name,NODE:.spec.nodeName,DEL:.metadata.deletionTimestamp 2>/dev/null \
    | awk -v n="$nodes" -v t="$1" '$4=="<none>" && index(n, " "$3" ") && $1!=t {printf "%s/%s ", $1, $2}'
}

echo "Pools"
pool_checks team-a on-demand
pool_checks team-b spot

echo "Placement"
check_eq "team-a/etl: 4 pods Running on team-a nodes" "4 team-a" "$(live_running team-a app=etl) $(pod_node_labels team-a app=etl karpenter.sh/nodepool)"
why "kubectl -n team-a describe pod -l app=etl | tail -3"
check_eq "team-b/web: 3 pods Running on team-b (spot) nodes" "3 team-b spot" \
  "$(live_running team-b app=web) $(pod_node_labels team-b app=web karpenter.sh/nodepool) $(pod_node_labels team-b app=web karpenter.sh/capacity-type)"
check_eq "platform/metrics: 2 pods Running on the shared pool" "2 shared" "$(live_running platform app=metrics) $(pod_node_labels platform app=metrics karpenter.sh/nodepool)"
x="$(intruders team-a)$(intruders team-b)"
check_eq "No pod runs on another team's nodes" "" "${x% }"
why "A team pool's taint keeps others out; its label (selected by the team's pods) keeps the team in."

echo "guards"
check_pool_unchanged shared shared
check_workload_unchanged deploy/etl team-a etl
check_workload_unchanged deploy/web team-b web
check_workload_unchanged deploy/metrics platform metrics
check_eq "platform/metrics is unchanged (no selectors or tolerations added)" "$(baseline_get metricsspec)" \
  "$(kubectl -n platform get deploy metrics -o jsonpath='{.spec.template.spec}')"
check_only_karpenter_nodes
check_karpenter_up
