source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/apps.yaml
baseline_save gpu="pool_spec gpu" chat="res_of deploy/chat ai" eval="res_of deploy/eval ai" train="res_of deploy/train ai" \
  trainspec="kubectl -n ai get deploy train -o jsonpath='{.spec.template.spec}'"
karp_wait_running ai app=eval 1 60
karp_wait_running ai app=train 1 30
