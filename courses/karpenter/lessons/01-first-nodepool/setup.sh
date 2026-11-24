source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
apply_lesson manifests/web.yaml
baseline_save web="res_of deploy/web shop"
sleep 2
