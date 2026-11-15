source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
apply_lesson manifests/jobsets.yaml
info "jobsets ddp-a and ddp-b (2 workers each) are running side by side, outside the queue"
