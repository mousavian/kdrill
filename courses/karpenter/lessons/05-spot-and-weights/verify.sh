source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=batch
SP=nodepool/spot

echo "NodePool spot"
check_eq "NodePool spot exists" spot "$(jp $SP '{.metadata.name}')"
check_eq "spot launches only spot capacity" "In spot" \
  "$(jp $SP '{.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].operator} {.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].values[*]}')"
check_eq "spot is limited to 16 CPUs" 16 "$(jp $SP '{.spec.limits.cpu}')"
w="$(jp $SP '{.spec.weight}')"; wod="$(jp nodepool/on-demand '{.spec.weight}')"
check "spot has a higher weight than on-demand (spot: ${w:-none}, on-demand: ${wod:-none})" awk -v a="${w:-0}" -v b="${wod:-0}" 'BEGIN{exit !(a > b)}'
why "Karpenter tries NodePools in order of spec.weight (1-100, unset counts as 0), highest first."

echo "render"
check_eq "render: scaled to 10, all Running" "10 10" "$(jp deploy/render '{.spec.replicas}' -n $NS) $(live_running $NS app=render)"
spread="$(pod_spread $NS app=render karpenter.sh/capacity-type)"
check_eq "render runs on spot and overflows to on-demand" "on-demand spot" "$(echo "$spread" | tr ' ' '\n' | cut -d: -f1 | paste -sd' ' -)"
why "Now: ${spread:-none}. Create the spot pool before scaling render, so Karpenter tries spot first and falls back when the 16-CPU budget runs out."
cpu="$(karp_capacity cpu karpenter.sh/nodepool=spot)"
check "Spot nodes total at most 16 CPUs (now: $cpu)" awk -v c="$cpu" 'BEGIN{exit !(c <= 16)}'
check_eq "render is not pinned to a capacity type" "" \
  "$(jp deploy/render '{.spec.template.spec.nodeSelector}{.spec.template.spec.affinity}' -n $NS)"
why "Let the NodePool weights decide; a nodeSelector would stop the fallback."

echo "api"
check_eq "api: 4 pods Running" 4 "$(live_running $NS app=api)"
check_eq "api asks for on-demand capacity (nodeSelector or required affinity)" yes \
  "$(hard_node_rule deploy/api karpenter.sh/capacity-type on-demand && echo yes)"
why "Without it, consolidation or the next rollout moves api to the cheaper, higher-weight spot pool."
check_eq "api runs only on on-demand nodes" on-demand "$(pod_node_labels $NS app=api karpenter.sh/capacity-type)"

echo "guards"
check_pool_unchanged on-demand ondemand
check_workload_unchanged deploy/api $NS api
check_eq "render keeps its requests (2 CPU, 4Gi per pod)" "$(baseline_get render)" \
  "$(kubectl -n $NS get deploy render -o jsonpath='{range .spec.template.spec.containers[*]}{.resources}{end}')"
check_only_karpenter_nodes
check_karpenter_up
