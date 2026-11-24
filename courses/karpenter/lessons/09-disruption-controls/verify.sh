source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=pay
NP=nodepool/default
B='{.spec.disruption.budgets'

echo "ledger"
lp="$(running_pod app=ledger)"
check_eq "ledger's original pod is still Running (never restarted)" "$(baseline_get ledger)" "$(jp pod/$lp '{.metadata.uid}' -n $NS)"
why "Annotating or editing the Deployment's pod template restarts the pod. Protect the running pod itself. (kdrill reset to start over.)"
check_eq "The running ledger pod has karpenter.sh/do-not-disrupt: \"true\"" true "$(jp pod/$lp '{.metadata.annotations.karpenter\.sh/do-not-disrupt}' -n $NS)"

echo "api"
pdb="$(kubectl -n $NS get pdb -o jsonpath='{range .items[?(@.spec.selector.matchLabels.app=="api")]}{.spec.maxUnavailable}/{.spec.minAvailable}{" "}{end}' 2>/dev/null)"
check "A PodDisruptionBudget for app=api allows exactly one api pod down (maxUnavailable 1 or minAvailable 2)" \
  bash -c '[[ "$1" == "1/ " || "$1" == "/2 " ]]' _ "$pdb"
why "Found: ${pdb:-none}. maxUnavailable 0 would block every drain of api's node."
check_eq "api: 3 pods Running" 3 "$(live_running $NS app=api)"

echo "NodePool default"
check_eq "Always-on budget: at most 1 node disrupted at a time" 1 \
  "$(jp $NP "$B[?(@.nodes==\"1\")].nodes}" | tr ' ' '\n' | head -1)"
check_eq "  ...that budget has no schedule and no reasons (applies always, to everything)" "" \
  "$(jp $NP "$B[?(@.nodes==\"1\")].schedule}$B[?(@.nodes==\"1\")].reasons}")"
sched="$(jp $NP "$B[?(@.nodes==\"0\")].reasons[*]}|$B[?(@.nodes==\"0\")].schedule}|$B[?(@.nodes==\"0\")].duration}")"
check "Business-hours budget: nodes 0, reasons [Drifted], schedule weekdays 09:00 UTC, duration 8h" \
  bash -c 'IFS="|" read -r r s d <<<"$1"; [[ "$r" == Drifted && ( "$s" == "0 9 * * mon-fri" || "$s" == "0 9 * * 1-5" ) && ( "$d" == 8h || "$d" == 8h0m0s ) ]]' _ "$sched"
why "Found: ${sched:-none}. Fields: nodes, reasons, schedule (cron, UTC), duration."
ca="$(jp $NP '{.spec.disruption.consolidateAfter}')"
check "Consolidation is on: consolidateAfter is 30s or less (now: ${ca:-unset})" bash -c '
  d="$1"; [[ "$d" =~ ^([0-9]+h)?([0-9]+m)?([0-9]+s)?$ && -n "$d" ]] || exit 1
  s=0; [[ "$d" =~ ([0-9]+)h ]] && s=$((s + BASH_REMATCH[1]*3600)); [[ "$d" =~ ([0-9]+)m ]] && s=$((s + BASH_REMATCH[1]*60)); [[ "$d" =~ ([0-9]+)s ]] && s=$((s + BASH_REMATCH[1])); (( s <= 30 ))' _ "$ca"
check_eq "consolidationPolicy is still WhenEmptyOrUnderutilized" WhenEmptyOrUnderutilized "$(jp $NP '{.spec.disruption.consolidationPolicy}')"

echo "Fleet"
check_ge "Karpenter consolidated an underutilized node" 1 "$(events_since DisruptionTerminating Underutilized)"
why "Takes ~30-90 s after consolidation is switched on. kubectl get events -A --field-selector reason=DisruptionTerminating"
ln="$(jp pod/$lp '{.spec.nodeName}' -n $NS)"
lcpu="$(cpu_millis "$(jp node/$ln '{.status.capacity.cpu}')")"
total="$(karp_capacity cpu karpenter.sh/nodepool=default)"
check "Apart from ledger's node, the fleet has at most 4 vCPUs (now: $(awk -v t="$total" -v l="$lcpu" 'BEGIN{print t - l/1000}'))" \
  awk -v t="$total" -v l="$lcpu" 'BEGIN{exit !(t - l/1000 <= 4)}'

echo "guards"
check_eq "NodePool template and limits unchanged" "$(baseline_get reqs)" "$(kubectl get nodepool default -o jsonpath='{.spec.template}|{.spec.limits}')"
check_workload_unchanged deploy/api $NS api
check_workload_unchanged deploy/ledger $NS ledgerspec
check_only_karpenter_nodes
check_karpenter_up
