source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=shop
NP=nodepool/default

echo "NodePool default"
check_eq "consolidationPolicy is WhenEmptyOrUnderutilized" WhenEmptyOrUnderutilized "$(jp $NP '{.spec.disruption.consolidationPolicy}')"
why "WhenEmpty only removes nodes with no (non-daemon) pods. Half-empty nodes need WhenEmptyOrUnderutilized."
ca="$(jp $NP '{.spec.disruption.consolidateAfter}')"
check "consolidateAfter is 30s or less (now: ${ca:-unset})" bash -c '
  d="$1"; [[ "$d" =~ ^([0-9]+h)?([0-9]+m)?([0-9]+s)?$ && -n "$d" ]] || exit 1
  s=0; [[ "$d" =~ ([0-9]+)h ]] && s=$((s + BASH_REMATCH[1]*3600)); [[ "$d" =~ ([0-9]+)m ]] && s=$((s + BASH_REMATCH[1]*60)); [[ "$d" =~ ([0-9]+)s ]] && s=$((s + BASH_REMATCH[1])); (( s <= 30 ))' _ "$ca"

echo "Fleet"
check_eq "web 2 and worker 1 pods Running" "2 1" "$(live_running $NS app=web) $(live_running $NS app=worker)"
cpu="$(karp_capacity cpu karpenter.sh/nodepool=default)"
check "The fleet shrank to at most 4 vCPUs (now: $cpu)" awk -v c="$cpu" 'BEGIN{exit !(c <= 4)}'
why "Consolidation needs ~30-90 s: consolidateAfter, then a short validation, then launch-before-drain. Watch: kubectl get nodeclaims -w; kubectl get events -A --field-selector reason=DisruptionTerminating"
check_ge "Karpenter consolidated nodes as Underutilized (DisruptionTerminating events)" 1 "$(events_since DisruptionTerminating Underutilized)"
why "Deleting nodes by hand isn't consolidation. kdrill reset and let Karpenter do it."

echo "guards"
check_workload_unchanged deploy/web $NS web
check_workload_unchanged deploy/worker $NS worker
check_only_karpenter_nodes
check_karpenter_up
