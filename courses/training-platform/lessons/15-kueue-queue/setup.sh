source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
# Cluster-scoped Kueue objects carry the lesson label so cleanup removes them.
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
apply_lesson manifests/jobs.yaml
info "exp-a and exp-b are running side by side, outside the queue"
