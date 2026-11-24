source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/web.yaml
karp_wait_running web app=web 3 40
apply_lesson manifests/ml-batch.yaml
baseline_save web="res_of deploy/web web" ml="res_of deploy/ml-batch web"
sleep 3
