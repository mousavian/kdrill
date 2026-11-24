ZONE=topology.kubernetes.io/zone
SPEC='{.spec.template.spec'
TSC="$SPEC.topologySpreadConstraints[?(@.topologyKey==\"$ZONE\")]"

check_eq "api still has 6 replicas" 6 "$(jp deploy/api '{.spec.replicas}')"
check_eq "api: 6 pods ready" 6 "$(jp deploy/api '{.status.readyReplicas}')"
why "If pods are Pending, describe one: a leftover rule may be excluding the zones you need."

check_eq "Pods per zone" "a:2 b:2 c:2" "$(pod_distribution app=api $ZONE)"
why "Expected exactly 2 pods in each zone. Check: kubectl get pods -o wide -l app=api"

check_eq "No nodeSelector on the zone any more" "" "$(jp deploy/api "$SPEC.nodeSelector.topology\\.kubernetes\\.io/zone}")"
why "The colleague's nodeSelector pins everything to zone a. Remove it."
req_keys="$(jp deploy/api "$SPEC.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions[*].key}")"
check "No required node affinity on the zone" bash -c '[[ "$1" != *topology.kubernetes.io/zone* ]]' _ "$req_keys"

check_eq "A spread constraint exists on topology.kubernetes.io/zone" "$ZONE" "$(jp deploy/api "$TSC.topologyKey}")"
why "Add spec.template.spec.topologySpreadConstraints with topologyKey: topology.kubernetes.io/zone."
check_eq "  maxSkew is 1" 1 "$(jp deploy/api "$TSC.maxSkew}")"
check_eq "  whenUnsatisfiable is DoNotSchedule" DoNotSchedule "$(jp deploy/api "$TSC.whenUnsatisfiable}")"
why "ScheduleAnyway is only a preference; the task asks for a hard constraint."
sel_ml="$(jp deploy/api "$TSC.labelSelector.matchLabels.app}")"
sel_me="$(jp deploy/api "$TSC.labelSelector.matchExpressions[?(@.key==\"app\")].values[*]}")"
check "  labelSelector selects the api pods (app=api)" bash -c '[[ "$1" == api || " $2 " == *" api "* ]]' _ "$sel_ml" "$sel_me"
why "Without a labelSelector that matches your pods, the constraint counts nothing. Use matchLabels: {app: api}."

check_eq "There are still exactly 6 worker nodes" 6 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
want="a:2 b:2 c:2"
got="$(kubectl get nodes -l type=kwok -o jsonpath='{range .items[*]}{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}{end}' | sort | uniq -c | awk '{printf "%s%s:%s", (NR>1?" ":""), $2, $1}')"
check_eq "Zone labels on the nodes are unchanged" "$want" "$got"
