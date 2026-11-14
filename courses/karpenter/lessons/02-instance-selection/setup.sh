source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/apps.yaml
baseline_save api="res_of deploy/api apps" worker="res_of deploy/worker apps"
sleep 3
