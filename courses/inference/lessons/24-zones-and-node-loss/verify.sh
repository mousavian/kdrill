source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
T='{.spec.template.spec.topologySpreadConstraints[?(@.topologyKey=="topology.kubernetes.io/zone")]'
skew="$(jp deploy/llm "$T.maxSkew}")"; when="$(jp deploy/llm "$T.whenUnsatisfiable}")"
check "topologySpreadConstraints on topology.kubernetes.io/zone with maxSkew 1 (got: ${skew:-none})" bash -c '[[ "$1" == 1 ]]' _ "$skew"
check_eq "... whenUnsatisfiable DoNotSchedule (a hard rule: ScheduleAnyway lets pods pile up again)" DoNotSchedule "$when"
check "The leftover zone-a preference is gone" bash -c '[[ -z "$(kubectl get deploy llm -o jsonpath="{.spec.template.spec.affinity.nodeAffinity}")" ]]'
why "It fights the spread constraint: kubectl edit deploy llm"
pdb="$(kubectl get pdb -o jsonpath='{range .items[*]}{.spec.selector.matchLabels.app}|{.spec.minAvailable}|{.spec.maxUnavailable}{"\n"}{end}' 2>/dev/null | awk -F'|' '$1=="llm"{print; exit}')"
pmin="$(echo "$pdb" | awk -F'|' '{print $2}')"; pmax="$(echo "$pdb" | awk -F'|' '{print $3}')"
check "A PodDisruptionBudget on app=llm allows at most 2 replicas down (minAvailable >= 4 or maxUnavailable <= 2; got: ${pdb:-none})" \
  bash -c '[[ -n "$1" ]] && { [[ "$2" =~ ^[0-9]+$ && "$2" -ge 4 ]] || [[ "$3" =~ ^[0-9]+$ && "$3" -le 2 ]]; }' _ "$pdb" "$pmin" "$pmax"
_spread() { [[ "$(pod_distribution app=llm topology.kubernetes.io/zone)" == "zone-a:2 zone-b:2 zone-c:2" ]]; }
(( _KD_FAIL == 0 )) && { wait_until 60 _spread || true; }
check_eq "Six replicas Running, two in each zone" "zone-a:2 zone-b:2 zone-c:2" "$(pod_distribution app=llm topology.kubernetes.io/zone)"
why "kubectl get pods -o wide shows the nodes; kubectl get nodes -L topology.kubernetes.io/zone maps nodes to zones."
if (( _KD_FAIL == 0 )); then
  # the node-loss drill: zone-a's node disappears
  kubectl delete node gpu-a --wait=false >/dev/null 2>&1
  _recovered() { [[ "$(live_count Running app=llm)" == 6 ]] && [[ "$(kubectl get pods -l app=llm -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | grep -c '^gpu-a$')" == 0 ]]; }
  wait_until 90 _recovered || true
  check_eq "Node loss drill (node gpu-a deleted): 6 replicas Running again, none on the lost node" 1 "$(_recovered && echo 1 || echo 0)"
  why "The Deployment recreates pods lost with the node; the scheduler must find room on the remaining nodes."
  d="$(pod_distribution app=llm topology.kubernetes.io/zone)"
  check_eq "... spread over the surviving zones (3 + 3)" "zone-b:3 zone-c:3" "$d"
  gpu_node gpu-a h100 4 --cpu 96 --mem 1024Gi --label "topology.kubernetes.io/zone=zone-a"   # the node comes back for the next verify
  wait_nodes_ready 60s || true
  # Back to 2 + 2 + 2 so that verify can be run again. The scheduler never moves running pods, so
  # delete one replica in each surviving zone: the hard spread rule sends the replacements to zone-a.
  for n in gpu-b gpu-c; do
    p="$(kubectl get pods -l app=llm --field-selector "spec.nodeName=$n" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [[ -n "$p" ]] && kubectl delete pod "$p" --wait=false >/dev/null 2>&1
  done
  wait_until 60 _spread || true
else
  echo "(the node-loss drill runs once the checks above pass)"
fi
