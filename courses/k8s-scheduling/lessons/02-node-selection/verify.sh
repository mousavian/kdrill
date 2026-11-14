DB='deploy/db'
CA='deploy/cache'
SPEC='{.spec.template.spec'

check_eq "db still has 2 replicas" 2 "$(jp $DB '{.spec.replicas}')"
check_eq "cache still has 2 replicas" 2 "$(jp $CA '{.spec.replicas}')"
why "Don't scale the workloads — change where they are allowed to run."

check_eq "db: 2 pods ready" 2 "$(jp $DB '{.status.readyReplicas}')"
why "If a db pod is Pending, its rule matches no node. Check the label values with: kubectl get nodes --show-labels"
check_eq "cache: 2 pods ready" 2 "$(jp $CA '{.status.readyReplicas}')"
why "cache must still be able to run anywhere. A required (hard) rule on zone can leave it Pending."

check "Every db pod is Running on a disktype=ssd node" pods_on_nodes_with app=db disktype=ssd
why "At least one db pod is on an hdd node. Look at: kubectl get pods -o wide -l app=db"

check "db pod template has a hard rule: disktype must be ssd" hard_node_rule deploy/db disktype ssd
why "Pods landing on ssd by luck is not enough. Add a nodeSelector, or a requiredDuringScheduling nodeAffinity with operator In and value ssd."

zone_ns="$(jp $CA "$SPEC.nodeSelector.topology\\.kubernetes\\.io/zone}")"
zone_req="$(jp $CA "$SPEC.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions[*].key}")"
check_eq "cache has no nodeSelector on zone" "" "$zone_ns"
why "cache should only *prefer* zone a. Remove the hard rule."
check "cache has no required node affinity on zone" bash -c '[[ "$1" != *topology.kubernetes.io/zone* ]]' _ "$zone_req"
why "cache should only *prefer* zone a. Remove the hard rule."

pref_key="$(jp $CA "$SPEC.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[*].preference.matchExpressions[?(@.key==\"topology.kubernetes.io/zone\")].key}")"
pref_val="$(jp $CA "$SPEC.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[*].preference.matchExpressions[?(@.key==\"topology.kubernetes.io/zone\")].values[*]}")"
check "cache has a preferred node affinity for zone a" bash -c '[[ -n "$1" && " $2 " == *" a "* ]]' _ "$pref_key" "$pref_val"
why "Use affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution with key topology.kubernetes.io/zone, operator In, values [a]."

check_eq "There are still exactly 4 worker nodes" 4 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
want="node-1:a:ssd node-2:a:hdd node-3:b:ssd node-4:b:hdd"
got=""
for n in node-1 node-2 node-3 node-4; do
  got+="$n:$(jp node/$n '{.metadata.labels.topology\.kubernetes\.io/zone}'):$(jp node/$n '{.metadata.labels.disktype}') "
done
check_eq "Node labels are unchanged" "$want" "${got% }"
why "Relabelling nodes is cheating: the hdd nodes really have hdd disks. Change the pods, not the nodes."
