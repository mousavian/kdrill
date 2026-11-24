source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
apply_lesson manifests/capstone.yaml
info "jobset/capstone created. manifests/sample.yaml samples the final model. Good luck."
