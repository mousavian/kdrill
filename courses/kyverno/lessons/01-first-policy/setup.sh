source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
apply_lesson manifests/web.yaml
wait_rollout deploy/web 60s shop || true
kyv_apply manifests/policy.yaml
