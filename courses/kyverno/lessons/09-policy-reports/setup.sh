source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
apply_lesson manifests/workloads.yaml
kyv_apply manifests/policy.yaml
