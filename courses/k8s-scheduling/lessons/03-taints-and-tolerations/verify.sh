check_eq "trainer still has 2 replicas" 2 "$(jp deploy/trainer '{.spec.replicas}')"
check_eq "trainer: 2 pods ready" 2 "$(jp deploy/trainer '{.status.readyReplicas}')"
why "Pending pods? kubectl describe pod <trainer-pod> shows which taint or resource is blocking them."

check "Every trainer pod is Running on a pool=ml node" pods_on_nodes_with app=trainer pool=ml
why "trainer pods must end up on the ML nodes: kubectl get pods -o wide -l app=trainer"

tol_key="$(jp deploy/trainer '{.spec.template.spec.tolerations[?(@.key=="dedicated")].key}')"
check_eq "trainer tolerates the 'dedicated' taint" dedicated "$tol_key"
why "Add a toleration with key: dedicated (operator Equal + value ml, or operator Exists), effect NoSchedule."

check "trainer has a hard rule: pool must be ml" hard_node_rule deploy/trainer pool ml
why "A toleration only PERMITS a node, it does not attract the pod. Add a nodeSelector (pool: ml) or required node affinity so trainer can never land on the general nodes."

for n in ml-1 ml-2; do
  check_eq "$n is still tainted dedicated=ml:NoSchedule" "ml:NoSchedule" \
    "$(jp node/$n '{.spec.taints[?(@.key=="dedicated")].value}'):$(jp node/$n '{.spec.taints[?(@.key=="dedicated")].effect}')"
  why "Removing the taint opens the ML pool to everybody. Keep it; give the pods a toleration instead."
done

check "No web pod is on an ML node" pods_none_on_nodes_with app=web pool=ml
why "web must stay on the general nodes."
check_eq "web is untouched: 2 replicas ready" 2 "$(jp deploy/web '{.status.readyReplicas}')"
check_eq "web has no tolerations" "" "$(jp deploy/web '{.spec.template.spec.tolerations}')"
why "Don't give web a toleration; only trainer is allowed on the ML pool."
check_eq "There are still exactly 4 worker nodes" 4 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
