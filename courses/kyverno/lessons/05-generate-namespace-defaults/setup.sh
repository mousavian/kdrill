source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kubectl label ns team-a tenant=team-a --overwrite >/dev/null
kubectl label ns team-b tenant=team-b --overwrite >/dev/null
apply_lesson manifests/namespaces.yaml
kyv_apply manifests/policy.yaml
