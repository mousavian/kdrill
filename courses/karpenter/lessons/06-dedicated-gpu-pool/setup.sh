source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepools.yaml
apply_lesson manifests/apps.yaml
gpu_rest() { kubectl get nodepool gpu -o jsonpath='{.spec.template.spec.requirements}|{.spec.limits}|{.spec.template.spec.nodeClassRef}' 2>/dev/null; }
baseline_save general="pool_spec general" gpurest="gpu_rest" web="res_of deploy/web ml" inference="res_of deploy/inference ml"
karp_wait_running ml app=web 3 60
karp_wait_running ml app=inference 2 30
