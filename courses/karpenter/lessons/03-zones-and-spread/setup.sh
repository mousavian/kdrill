source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/apps.yaml
baseline_save general="pool_spec general" checkout="res_of deploy/checkout store" reports="res_of deploy/reports store"
karp_wait_running store app=checkout 6 60
