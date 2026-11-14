source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/api.yaml
karp_wait_running pay app=api 3 60
karp_wait_running pay app=settlement 12 30
apply_lesson manifests/ledger.yaml
karp_wait_running pay app=ledger 1 60
kubectl -n pay scale deploy settlement --replicas=0 >/dev/null
ledger_uid() { kubectl -n pay get pods -l app=ledger -o jsonpath='{.items[*].metadata.uid}'; }
wait_until 30 bash -c '[[ "$(kubectl -n pay get pods -l app=settlement --no-headers 2>/dev/null | wc -l)" -eq 0 ]]' || true
baseline_save ledger="ledger_uid" api="res_of deploy/api pay" ledgerspec="res_of deploy/ledger pay" reqs="kubectl get nodepool default -o jsonpath='{.spec.template}|{.spec.limits}'"
