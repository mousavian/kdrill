source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/api.yaml
karp_wait_running fleet app=api 4 60
first_nodes() { kubectl get nodeclaims -o jsonpath='{.items[*].metadata.name}'; }
baseline_save api="res_of deploy/api fleet" claims="first_nodes"
