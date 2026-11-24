source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
kubectl label ns research cost-center=cc-1001 --overwrite >/dev/null
kubectl label ns inference cost-center=cc-2002 --overwrite >/dev/null
apply_lesson manifests/workloads.yaml
kyv_apply manifests/policy.yaml
