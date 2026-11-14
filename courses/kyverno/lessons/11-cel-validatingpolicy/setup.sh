source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kyv_apply manifests/clusterpolicy.yaml
apply_lesson manifests/draft-validatingpolicy.yaml manifests/ranker.yaml
wait_rollout deploy/ranker 60s ml-serving || true
