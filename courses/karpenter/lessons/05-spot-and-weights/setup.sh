source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/apps.yaml
baseline_save ondemand="pool_spec on-demand" api="res_of deploy/api batch" render="kubectl -n batch get deploy render -o jsonpath='{range .spec.template.spec.containers[*]}{.resources}{end}'"
karp_wait_running batch app=api 4 60
