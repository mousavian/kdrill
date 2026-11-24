source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kyv_apply manifests/policy.yaml
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/exception-attempt.yaml" >/dev/null 2>&1 || true
