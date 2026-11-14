source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kubectl label ns prod env=prod --overwrite >/dev/null
kubectl label ns dev env=dev --overwrite >/dev/null
apply_lesson manifests/rbac.yaml
kyv_apply manifests/policy.yaml
wait_until 30 policy_ready require-run-as-nonroot || true
sleep 3
# Admitted (no autogen rule for Deployments), but its Pods are not.
apply_lesson manifests/api.yaml
