source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kubectl label ns ml-team gpu-access=approved --overwrite >/dev/null
apply_lesson manifests/config.yaml
kyv_apply manifests/policy.yaml
