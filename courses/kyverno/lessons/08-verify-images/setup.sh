source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kyv_apply manifests/policy.yaml
