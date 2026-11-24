source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepools.yaml
apply_lesson manifests/prod.yaml manifests/ml.yaml manifests/batch.yaml
karp_wait_running prod app=legacy 1 60
karp_wait_running ml app=rerank 1 30
karp_wait_running batch app=crunch 3 30
# The platform team re-labels the general pool's nodes (cost-center shop-v2):
# every general node is now drifted and should be replaced.
kubectl patch nodepool general --type merge -p '{"spec":{"template":{"metadata":{"labels":{"cost-center":"shop-v2"}}}}}' >/dev/null
has_drift() { kubectl get nodeclaims -o jsonpath='{.items[*].status.conditions[?(@.type=="Drifted")].status}' | grep -q True; }
wait_until 30 has_drift || true
pools() { local p; for p in general spot gpu; do echo "$p=$(pool_spec $p)"; done; }
baseline_save pools="pools" \
  checkout="res_of deploy/checkout prod" legacy="res_of deploy/legacy prod" embed="res_of deploy/embed ml" \
  rerank="res_of deploy/rerank ml" crunch="res_of deploy/crunch batch"
sleep 3
