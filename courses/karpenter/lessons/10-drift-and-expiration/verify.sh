source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=fleet
NP=nodepool/default

echo "NodePool default"
check_eq "Requires kubernetes.io/arch In [arm64]" "In arm64" \
  "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="kubernetes.io/arch")].operator} {.spec.template.spec.requirements[?(@.key=="kubernetes.io/arch")].values[*]}')"
check_eq "Template labels nodes fleet=graviton-2026" graviton-2026 "$(jp $NP '{.spec.template.metadata.labels.fleet}')"
check_eq "expireAfter is 168h" 168h "$(jp $NP '{.spec.template.spec.expireAfter}')"
check_eq "terminationGracePeriod is 1h" 1h "$(jp $NP '{.spec.template.spec.terminationGracePeriod}')"
check_eq "Other requirements unchanged (on-demand, category m)" "on-demand m" \
  "$(jp $NP '{.spec.template.spec.requirements[?(@.key=="karpenter.sh/capacity-type")].values[*]} {.spec.template.spec.requirements[?(@.key=="karpenter.k8s.aws/instance-category")].values[*]}')"

echo "Fleet"
check_eq "api: 4 pods Running" 4 "$(live_running $NS app=api)"
check_eq "Every node is arm64" arm64 "$(karp_node_labels kubernetes.io/arch)"
why "Drift replacement takes ~20-60 s per node (kubectl get nodeclaims -w)."
check_eq "Every node carries fleet=graviton-2026" graviton-2026 "$(karp_node_labels fleet)"
old="$(baseline_get claims)"; left=""
for c in $old; do kubectl get nodeclaim "$c" >/dev/null 2>&1 && left+="$c "; done
check_eq "All nodes from before the change have been replaced" "" "${left% }"
check_ge "Karpenter replaced them as Drifted (DisruptionTerminating events)" 1 "$(events_since DisruptionTerminating Drifted)"
why "Deleting nodes by hand isn't drift. kdrill reset and let Karpenter roll the fleet."

echo "guards"
check_workload_unchanged deploy/api $NS api
check_eq "api's PodDisruptionBudget is still maxUnavailable 1" 1 "$(jp pdb/api '{.spec.maxUnavailable}' -n $NS)"
check_only_karpenter_nodes
check_karpenter_up
